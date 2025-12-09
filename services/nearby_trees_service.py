"""
Nearby Trees Service - combines user-planted trees (DB) with satellite data
"""
import json
from typing import List, Dict, Tuple, Optional
from pathlib import Path
from math import radians, sin, cos, sqrt, atan2

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from models import Tree


class NearbyTreesService:

    def __init__(self, json_file_path: str = "cords_tree.json", db: Optional[AsyncSession] = None):
        """
        Initialize service with both satellite and database trees

        Args:
            json_file_path: Path to JSON file with satellite tree coordinates
            db: Database session for querying user-planted trees
        """
        self.json_path = Path(json_file_path)
        self.db = db
        self.satellite_trees = self._load_satellite_data()

    def _load_satellite_data(self) -> List[Dict]:
        """Load tree coordinates from JSON file (satellite data)"""
        try:
            with open(self.json_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                return data.get('predictions', [])
        except FileNotFoundError:
            print(f"Warning: {self.json_path} not found. No satellite trees loaded.")
            return []
        except json.JSONDecodeError as e:
            print(f"Error parsing JSON: {e}")
            return []

    @staticmethod
    def _calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """
        Calculate distance between two points in meters using Haversine formula
        """
        R = 6371000  # Earth radius in meters

        lat1_rad = radians(lat1)
        lat2_rad = radians(lat2)
        dlat = radians(lat2 - lat1)
        dlon = radians(lon2 - lon1)

        a = sin(dlat/2)**2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon/2)**2
        c = 2 * atan2(sqrt(a), sqrt(1-a))

        return R * c

    @staticmethod
    def _calculate_centroid(segments: List[List[float]]) -> Tuple[float, float]:
        """
        Calculate centroid (center point) from polygon segments
        """
        if not segments:
            return 0.0, 0.0

        lats = [seg[0] for seg in segments]
        lons = [seg[1] for seg in segments]

        return sum(lats) / len(lats), sum(lons) / len(lons)

    async def _get_db_trees_nearby(
        self,
        user_lat: float,
        user_lon: float,
        radius_km: float
    ) -> List[Dict]:
        """
        Get user-planted trees from database within radius
        """
        if not self.db:
            return []

        # Query all active trees from database
        query = select(Tree).where(Tree.status == "active")
        result = await self.db.execute(query)
        db_trees = result.scalars().all()

        nearby_db_trees = []

        for tree in db_trees:
            # Use centroid if available, otherwise use original GPS
            tree_lat = tree.centroid_lat if tree.centroid_lat else tree.latitude
            tree_lon = tree.centroid_lon if tree.centroid_lon else tree.longitude

            # Calculate distance
            distance_m = self._calculate_distance(
                user_lat, user_lon,
                tree_lat, tree_lon
            )
            distance_km = distance_m / 1000

            # Check if within radius
            if distance_km <= radius_km:
                nearby_db_trees.append({
                    'tree_id': tree.id,
                    'source': 'user_planted',  # Mark as user-planted
                    'user_id': tree.user_id,
                    'phase': tree.phase,
                    'status': tree.status,
                    'health': tree.last_health,
                    'soil_moisture': tree.last_soil_moisture,
                    'centroid_lat': tree_lat,
                    'centroid_lon': tree_lon,
                    'segments': tree.segments or [],
                    'distance_meters': round(distance_m, 2),
                    'distance_km': round(distance_km, 3),
                    'created_at': tree.created_at.isoformat() if tree.created_at else None,
                })

        return nearby_db_trees

    def _get_satellite_trees_nearby(
        self,
        user_lat: float,
        user_lon: float,
        radius_km: float
    ) -> List[Dict]:
        """
        Get satellite-detected trees from JSON within radius
        """
        nearby_satellite_trees = []

        for tree in self.satellite_trees:
            segments = tree.get('segments', [])
            if not segments:
                continue

            centroid_lat, centroid_lon = self._calculate_centroid(segments)

            distance_m = self._calculate_distance(
                user_lat, user_lon,
                centroid_lat, centroid_lon
            )
            distance_km = distance_m / 1000

            if distance_km <= radius_km:
                nearby_satellite_trees.append({
                    'tree_id': f"sat_{tree.get('class_id', 0)}_{hash(str(segments[:3])) % 10000}",
                    'source': 'satellite',  # Mark as satellite-detected
                    'class_name': tree.get('class_name', 'tree'),
                    'confidence': tree.get('confidence', 0.0),
                    'centroid_lat': centroid_lat,
                    'centroid_lon': centroid_lon,
                    'segments': segments,
                    'distance_meters': round(distance_m, 2),
                    'distance_km': round(distance_km, 3),
                    'box': tree.get('box', {}),
                })

        return nearby_satellite_trees

    async def get_nearby_trees(
        self,
        user_lat: float,
        user_lon: float,
        radius_km: float = 2.0,
        limit: int = 50,
        include_satellite: bool = True,
        include_user_planted: bool = True
    ) -> List[Dict]:
        """
        Find trees near user's location from both database and satellite data

        Args:
            user_lat: User's latitude
            user_lon: User's longitude
            radius_km: Search radius in kilometers (default: 2km)
            limit: Maximum number of trees to return
            include_satellite: Include satellite-detected trees
            include_user_planted: Include user-planted trees from database

        Returns:
            Combined list of nearby trees sorted by distance
        """
        all_nearby_trees = []

        # Get user-planted trees from database
        if include_user_planted:
            db_trees = await self._get_db_trees_nearby(user_lat, user_lon, radius_km)
            all_nearby_trees.extend(db_trees)

        # Get satellite-detected trees
        if include_satellite:
            sat_trees = self._get_satellite_trees_nearby(user_lat, user_lon, radius_km)
            all_nearby_trees.extend(sat_trees)

        # Sort by distance (closest first)
        all_nearby_trees.sort(key=lambda x: x['distance_meters'])

        # Apply limit
        return all_nearby_trees[:limit]

    async def get_tree_details(self, tree_id: str) -> Dict:
        """
        Get detailed information about a specific tree (from DB or satellite)

        Args:
            tree_id: Tree identifier

        Returns:
            Tree details or empty dict if not found
        """
        # Check if it's a user-planted tree (UUID format)
        if not tree_id.startswith('sat_'):
            if self.db:
                query = select(Tree).where(Tree.id == tree_id)
                result = await self.db.execute(query)
                tree = result.scalar_one_or_none()

                if tree:
                    tree_lat = tree.centroid_lat if tree.centroid_lat else tree.latitude
                    tree_lon = tree.centroid_lon if tree.centroid_lon else tree.longitude

                    return {
                        'tree_id': tree.id,
                        'source': 'user_planted',
                        'user_id': tree.user_id,
                        'phase': tree.phase,
                        'status': tree.status,
                        'health': tree.last_health,
                        'soil_moisture': tree.last_soil_moisture,
                        'centroid_lat': tree_lat,
                        'centroid_lon': tree_lon,
                        'segments': tree.segments or [],
                        'created_at': tree.created_at.isoformat() if tree.created_at else None,
                    }

        # Otherwise, search in satellite data
        try:
            tree_hash = int(tree_id.split('_')[-1])
        except (ValueError, IndexError):
            return {}

        for tree in self.satellite_trees:
            segments = tree.get('segments', [])
            if not segments:
                continue

            current_hash = hash(str(segments[:3])) % 10000
            if current_hash == tree_hash:
                centroid_lat, centroid_lon = self._calculate_centroid(segments)

                return {
                    'tree_id': tree_id,
                    'source': 'satellite',
                    'class_name': tree.get('class_name', 'tree'),
                    'confidence': tree.get('confidence', 0.0),
                    'centroid_lat': centroid_lat,
                    'centroid_lon': centroid_lon,
                    'segments': segments,
                    'box': tree.get('box', {}),
                    'segment_count': len(segments)
                }

        return {}

    async def get_trees_in_bounds(
        self,
        north: float,
        south: float,
        east: float,
        west: float,
        include_satellite: bool = True,
        include_user_planted: bool = True
    ) -> List[Dict]:
        """
        Get all trees within a bounding box from both sources

        Args:
            north: Northern latitude boundary
            south: Southern latitude boundary
            east: Eastern longitude boundary
            west: Western longitude boundary
            include_satellite: Include satellite trees
            include_user_planted: Include user-planted trees

        Returns:
            List of trees within bounds
        """
        trees_in_bounds = []

        # Get user-planted trees
        if include_user_planted and self.db:
            query = select(Tree).where(Tree.status == "active")
            result = await self.db.execute(query)
            db_trees = result.scalars().all()

            for tree in db_trees:
                tree_lat = tree.centroid_lat if tree.centroid_lat else tree.latitude
                tree_lon = tree.centroid_lon if tree.centroid_lon else tree.longitude

                if (south <= tree_lat <= north and west <= tree_lon <= east):
                    trees_in_bounds.append({
                        'tree_id': tree.id,
                        'source': 'user_planted',
                        'user_id': tree.user_id,
                        'centroid_lat': tree_lat,
                        'centroid_lon': tree_lon,
                        'segments': tree.segments or [],
                        'phase': tree.phase,
                        'health': tree.last_health,
                    })

        # Get satellite trees
        if include_satellite:
            for tree in self.satellite_trees:
                segments = tree.get('segments', [])
                if not segments:
                    continue

                centroid_lat, centroid_lon = self._calculate_centroid(segments)

                if (south <= centroid_lat <= north and west <= centroid_lon <= east):
                    trees_in_bounds.append({
                        'tree_id': f"sat_{tree.get('class_id', 0)}_{hash(str(segments[:3])) % 10000}",
                        'source': 'satellite',
                        'class_name': tree.get('class_name', 'tree'),
                        'confidence': tree.get('confidence', 0.0),
                        'centroid_lat': centroid_lat,
                        'centroid_lon': centroid_lon,
                        'segments': segments,
                        'box': tree.get('box', {}),
                    })

        return trees_in_bounds

    async def get_statistics(self) -> Dict:
        """
        Get statistics about both satellite and user-planted trees

        Returns:
            Statistics dictionary
        """
        stats = {
            'satellite_trees': len(self.satellite_trees),
            'user_planted_trees': 0,
            'total_trees': len(self.satellite_trees),
        }

        # Get database tree count
        if self.db:
            query = select(Tree).where(Tree.status == "active")
            result = await self.db.execute(query)
            db_trees = result.scalars().all()
            stats['user_planted_trees'] = len(db_trees)
            stats['total_trees'] = stats['satellite_trees'] + stats['user_planted_trees']

        # Satellite statistics
        if self.satellite_trees:
            confidences = [t.get('confidence', 0.0) for t in self.satellite_trees]
            stats.update({
                'satellite_avg_confidence': round(sum(confidences) / len(confidences), 3),
                'satellite_min_confidence': round(min(confidences), 3),
                'satellite_max_confidence': round(max(confidences), 3),
            })

        return stats
