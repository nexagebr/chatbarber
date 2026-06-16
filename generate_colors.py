
import re
import colorsys

def rgb_to_hls(r, g, b):
    return colorsys.rgb_to_hls(r/255.0, g/255.0, b/255.0)

def hls_to_rgb(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return int(max(0, min(255, round(r * 255)))), int(max(0, min(255, round(g * 255)))), int(max(0, min(255, round(b * 255))))

# Old Base Blue-9
old_base_rgb = (39, 129, 246)
old_base_hls = rgb_to_hls(*old_base_rgb)
print(f"Old Base HLS: {old_base_hls}")

# New Base
new_base_hex = "#4241FF"
new_base_rgb = (66, 65, 255)
new_base_hls = rgb_to_hls(*new_base_rgb)
print(f"New Base HLS: {new_base_hls}")

# Calculate Deltas
delta_h = new_base_hls[0] - old_base_hls[0]
delta_l_ratio = new_base_hls[1] / old_base_hls[1]
delta_s_ratio = new_base_hls[2] / old_base_hls[2] if old_base_hls[2] > 0 else 1

print(f"Deltas: H={delta_h}, L_ratio={delta_l_ratio}, S_ratio={delta_s_ratio}")

def transform_color(r, g, b):
    h, l, s = rgb_to_hls(r, g, b)
    
    # Hue shift
    new_h = (h + delta_h) % 1.0
    
    # Lightness scaling
    if l > old_base_hls[1]:
        # Lighter than base: Scale remaining range to white
        # (1 - new_l) / (1 - new_base_l) = (1 - old_l) / (1 - old_base_l)
        # 1 - new_l = (1 - old_l) * ratio
        ratio = (1 - new_base_hls[1]) / (1 - old_base_hls[1])
        new_l = 1 - (1 - l) * ratio
    else:
        # Darker than base: Scale range to black
        # new_l / new_base_l = old_l / old_base_l
        ratio = new_base_hls[1] / old_base_hls[1]
        new_l = l * ratio
        
    # Saturation scaling (clamp to 1.0)
    new_s = min(1.0, s * delta_s_ratio)
    
    return hls_to_rgb(new_h, new_l, new_s)

# Paste the content of _next-colors.scss here (just the blue parts for now or read file)
# Since I can't interactively paste, I will hardcode the arrays from the file view I did earlier.

light_blues = [
    (251, 253, 255), # 1
    (245, 249, 255), # 2
    (233, 243, 255), # 3
    (218, 236, 255), # 4
    (201, 226, 255), # 5
    (181, 213, 255), # 6
    (155, 195, 252), # 7
    (117, 171, 247), # 8
    (39, 129, 246),  # 9 (Base)
    (16, 115, 233),  # 10
    (8, 109, 224),   # 11
    (11, 50, 101)    # 12
]

dark_blues = [
    (10, 17, 28),   # 1
    (15, 24, 38),   # 2
    (15, 39, 72),   # 3
    (10, 49, 99),   # 4
    (18, 61, 117),  # 5
    (29, 84, 134),  # 6
    (40, 89, 156),  # 7
    (48, 106, 186), # 8
    (39, 129, 246), # 9 (Base)
    (21, 116, 231), # 10
    (126, 182, 255),# 11
    (205, 227, 255) # 12
]

print("\n--- Light Blues ---")
for i, c in enumerate(light_blues):
    new_c = transform_color(*c)
    print(f"--blue-{i+1}: {new_c[0]} {new_c[1]} {new_c[2]};")

print("\n--- Dark Blues ---")
for i, c in enumerate(dark_blues):
    # For dark mode, lightness scaling might be inverse or different.
    # But let's apply the same logic first and see. 
    # Actually, for dark mode blue-9 is same as light mode blue-9.
    # So the transformation should hold? 
    new_c = transform_color(*c)
    print(f"--blue-{i+1}: {new_c[0]} {new_c[1]} {new_c[2]};")
