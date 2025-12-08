"""
Nearby Trees Service - finds trees near user's location from satellite data
"""
import json
from typing import List, Dict, Tuple
from pathlib import Path
from math import radians, sin, cos, sqrt, atan2


class NearbyTreesService:
    
    def __init__(self, json_file_path: str = "cords_tree.json"):
        """
        Initialize service with satellite tree data
        
        Args:
            json_file_path: Path to JSON file with tree coordinates
        """
        self.json_path = Path(json_file_path)
        self.trees_data = self._load_trees_data()
    
    def _load_trees_data(self) -> List[Dict]:
        """Load tree coordinates from JSON file"""
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
        
        Args:
            lat1, lon1: First point coordinates
            lat2, lon2: Second point coordinates
            
        Returns:
            Distance in meters
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
        
        Args:
            segments: List of [lat, lon] coordinates
            
        Returns:
            (centroid_lat, centroid_lon)
        """
        if not segments:
            return 0.0, 0.0
        
        lats = [seg[0] for seg in segments]
        lons = [seg[1] for seg in segments]
        
        return sum(lats) / len(lats), sum(lons) / len(lons)
    
    def get_nearby_trees(
        self,
        user_lat: float,
        user_lon: float,
        radius_km: float = 2.0,
        limit: int = 50
    ) -> List[Dict]:
        """
        Find trees near user's location
        
        Args:
            user_lat: User's latitude
            user_lon: User's longitude
            radius_km: Search radius in kilometers (default: 2km)
            limit: Maximum number of trees to return
            
        Returns:
            List of nearby trees with distance info
        """
        nearby_trees = []
        
        for tree in self.trees_data:
            # Get segments (polygon points of tree canopy)
            segments = tree.get('segments', [])
            if not segments:
                continue
            
            # Calculate centroid of tree
            centroid_lat, centroid_lon = self._calculate_centroid(segments)
            
            # Calculate distance from user to tree centroid
            distance_m = self._calculate_distance(
                user_lat, user_lon,
                centroid_lat, centroid_lon
            )
            distance_km = distance_m / 1000
            
            # Check if within radius
            if distance_km <= radius_km:
                nearby_trees.append({
                    'tree_id': f"sat_{tree.get('class_id', 0)}_{hash(str(segments[:3])) % 10000}",
                    'class_name': tree.get('class_name', 'tree'),
                    'confidence': tree.get('confidence', 0.0),
                    'centroid_lat': centroid_lat,
                    'centroid_lon': centroid_lon,
                    'segments': segments,
                    'distance_meters': round(distance_m, 2),
                    'distance_km': round(distance_km, 3),
                    'box': tree.get('box', {}),
                })
        
        # Sort by distance (closest first)
        nearby_trees.sort(key=lambda x: x['distance_meters'])
        
        # Apply limit
        return nearby_trees[:limit]
    
    def get_tree_details(self, tree_id: str) -> Dict:
        """
        Get detailed information about a specific satellite tree
        
        Args:
            tree_id: Tree identifier
            
        Returns:
            Tree details or empty dict if not found
        """
        # Extract hash from tree_id
        try:
            tree_hash = int(tree_id.split('_')[-1])
        except (ValueError, IndexError):
            return {}
        
        for tree in self.trees_data:
            segments = tree.get('segments', [])
            if not segments:
                continue
            
            current_hash = hash(str(segments[:3])) % 10000
            if current_hash == tree_hash:
                centroid_lat, centroid_lon = self._calculate_centroid(segments)
                
                return {
                    'tree_id': tree_id,
                    'class_name': tree.get('class_name', 'tree'),
                    'confidence': tree.get('confidence', 0.0),
                    'centroid_lat': centroid_lat,
                    'centroid_lon': centroid_lon,
                    'segments': segments,
                    'box': tree.get('box', {}),
                    'segment_count': len(segments)
                }
        
        return {}
    
    def get_trees_in_bounds(
        self,
        north: float,
        south: float,
        east: float,
        west: float
    ) -> List[Dict]:
        """
        Get all trees within a bounding box
        
        Args:
            north: Northern latitude boundary
            south: Southern latitude boundary
            east: Eastern longitude boundary
            west: Western longitude boundary
            
        Returns:
            List of trees within bounds
        """
        trees_in_bounds = []
        
        for tree in self.trees_data:
            segments = tree.get('segments', [])
            if not segments:
                continue
            
            centroid_lat, centroid_lon = self._calculate_centroid(segments)
            
            # Check if centroid is within bounds
            if (south <= centroid_lat <= north and 
                west <= centroid_lon <= east):
                
                trees_in_bounds.append({
                    'tree_id': f"sat_{tree.get('class_id', 0)}_{hash(str(segments[:3])) % 10000}",
                    'class_name': tree.get('class_name', 'tree'),
                    'confidence': tree.get('confidence', 0.0),
                    'centroid_lat': centroid_lat,
                    'centroid_lon': centroid_lon,
                    'segments': segments,
                    'box': tree.get('box', {}),
                })
        
        return trees_in_bounds
    
    def get_statistics(self) -> Dict:
        """
        Get statistics about loaded satellite trees
        
        Returns:
            Statistics dictionary
        """
        if not self.trees_data:
            return {
                'total_trees': 0,
                'avg_confidence': 0.0,
                'min_confidence': 0.0,
                'max_confidence': 0.0
            }
        
        confidences = [t.get('confidence', 0.0) for t in self.trees_data]
        
        return {
            'total_trees': len(self.trees_data),
            'avg_confidence': round(sum(confidences) / len(confidences), 3),
            'min_confidence': round(min(confidences), 3),
            'max_confidence': round(max(confidences), 3),
            'avg_segments_per_tree': round(
                sum(len(t.get('segments', [])) for t in self.trees_data) / len(self.trees_data),
                1
            )
        }
