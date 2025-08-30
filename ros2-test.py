#!/usr/bin/env python3

from pymavlink import mavutil
import time

# Constants
LAT_START = 15.36757925246701
LON_START = 75.1254539873025
ALT = 30
SPACING = 1  # ~16.7 m spacing
NUM_SWEEPS = 5

# Connect to PX4 SITL
master = mavutil.mavlink_connection('udp:localhost:14540')
master.wait_heartbeat()
print(f"Heartbeat received from system (system ID: {master.target_system})")

# Set mode to AUTO (PX4 does not support 'GUIDED' mode like ArduPilot)
master.set_mode_apm('AUTO')
print("Set mode to AUTO")
time.sleep(2)

# Arm
master.mav.command_long_send(
    master.target_system, master.target_component,
    mavutil.mavlink.MAV_CMD_COMPONENT_ARM_DISARM,
    0,
    1, 0, 0, 0, 0, 0, 0)
print("Sent arm command")
time.sleep(2)

# Takeoff
master.mav.command_long_send(
    master.target_system, master.target_component,
    mavutil.mavlink.MAV_CMD_NAV_TAKEOFF,
    0,
    0, 0, 0, 0,
    0, 0, ALT)
print("Sent takeoff command")
time.sleep(8)

# Generate boustrophedon waypoints
points = []
direction = 1
for i in range(NUM_SWEEPS):
    lat = LAT_START + i * SPACING
    if direction:
        points.append((lat, LON_START))
        points.append((lat, LON_START + SPACING * 5))
    else:
        points.append((lat, LON_START + SPACING * 5))
        points.append((lat, LON_START))
    direction ^= 1

# Clear any existing mission
master.mav.mission_clear_all_send(master.target_system, master.target_component)
print("Cleared previous mission")
time.sleep(2)

# Send mission count (number of waypoints)
num_points = len(points)
master.mav.mission_count_send(master.target_system, master.target_component, num_points)

# Send mission items one by one
for i, (lat, lon) in enumerate(points):
    try:
        msg = master.recv_match(type='MISSION_REQUEST', blocking=True, timeout=5)
        print(f"Sending waypoint {i}")
        master.mav.mission_item_int_send(
            master.target_system, master.target_component,
            i,
            mavutil.mavlink.MAV_FRAME_GLOBAL_RELATIVE_ALT_INT,
            mavutil.mavlink.MAV_CMD_NAV_WAYPOINT,
            0, 1,   # current, autocontinue
            2, 0, 0, 0,  # hold time + unused
            int(lat * 1e7),
            int(lon * 1e7),
            ALT)
        time.sleep(1)
    except Exception as e:
        print(f"Timeout waiting for MISSION_REQUEST for waypoint {i}")
        break

# Wait for mission ack
try:
    msg = master.recv_match(type='MISSION_ACK', blocking=True, timeout=5)
    print("Mission uploaded successfully")
except:
    print("MISSION_ACK not received")

time.sleep(2)

# Set mode to AUTO.MISSION (explicitly)
master.set_mode_apm('AUTO')
print("Set mode to AUTO.MISSION")
time.sleep(2)

# Start mission
master.mav.command_long_send(
    master.target_system, master.target_component,
    mavutil.mavlink.MAV_CMD_MISSION_START,
    0,
    0, 0, 0, 0, 0, 0, 0)
print("Mission started")

# Let mission complete
print("Waiting 60s for mission to run...")
time.sleep(60)

# Return to Launch (RTL)
master.mav.command_long_send(
    master.target_system, master.target_component,
    mavutil.mavlink.MAV_CMD_NAV_RETURN_TO_LAUNCH,
    0,
    0, 0, 0, 0, 0, 0, 0)
print("Sent RTL command")
