import os
from geopy.distance import distance
import folium

# --- USER INPUT ---
# O'zingizning jonli koordinatalaringizni shu yerga qo'ying:
user_lat = 41.33849111   # misol: Toshkent latitude
user_lon = 69.33535386   # misol: Toshkent longitude

# Kamera sizdan qancha uzoqlikda (metr)
camera_distance_m = 1000

# Kamera atrofidagi ko'rsatiladigan radius (metr)
camera_radius_m = 200

# Kamera qaysi yo'nalishda bo'lsin (gradus, 0 = shimol, 90 = sharq, 180 = janub, 270 = g'arb)
bearing_deg = 90  # misol: 90° = sharqqa

# --- COMPUTE DESTINATION POINT ---
# geopy.distance(...).destination expects a (lat, lon) tuple and bearing in degrees
origin = (user_lat, user_lon)
dest = distance(meters=camera_distance_m).destination(origin, bearing_deg)
camera_lat, camera_lon = dest.latitude, dest.longitude

# --- BUILD MAP WITH FOLIUM ---
# Create a folium map centered to show both origin and camera
mid_lat = (user_lat + camera_lat) / 2
mid_lon = (user_lon + camera_lon) / 2

m = folium.Map(location=[mid_lat, mid_lon], zoom_start=15)  # zoom_start is adjustable

# Add user location
folium.Marker(
    [user_lat, user_lon],
    popup="Siz (user)",
    icon=folium.Icon(color="blue", icon="user")
).add_to(m)

# Add camera location
folium.Marker(
    [camera_lat, camera_lon],
    popup=f"Kamera ({camera_distance_m} m, bearing {bearing_deg}°)",
    icon=folium.Icon(color="red", icon="camera")
).add_to(m)

# Add circle around camera (radius = camera_radius_m)
folium.Circle(
    radius=camera_radius_m,
    location=[camera_lat, camera_lon],
    popup=f"Radius: {camera_radius_m} m",
    fill=True,
    fill_opacity=0.2
).add_to(m)

# Optionally draw a line from user to camera
folium.PolyLine(locations=[(user_lat, user_lon), (camera_lat, camera_lon)], weight=2).add_to(m)

# Save map to HTML
out_html = "camera_area_map.html"
m.save(out_html)
print(f"Map saved to {out_html}")
print(f"User:  ({user_lat:.6f}, {user_lon:.6f})")
print(f"Camera:({camera_lat:.6f}, {camera_lon:.6f})")

# --- OPTIONAL: Save PNG screenshot of the HTML (headless Chrome) ---
# Requires: selenium, webdriver-manager, Chrome installed on system.
# If you don't want PNG, comment out the below block.

# --- OPTIONAL: Save PNG screenshot of the HTML (headless Chrome) ---
try:
    from html2image import Html2Image
    import time

    hti = Html2Image(
     browser='chromium-browser',
     custom_flags=[
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--disable-software-rasterizer',
        '--allow-file-access-from-files',
        '--allow-file-access',
        '--disable-web-security',
        '--ignore-certificate-errors'
     ]
     )

    time.sleep(2)

    hti.screenshot(
      html_file="camera_area_map.html",
     save_as="camera_area_map.png",
     size=(1200, 900),
     delay=3
    )

    print("PNG created successfully!")
except Exception as e:
    print("PNG export skipped or failed.")
    print("Error:", e)
