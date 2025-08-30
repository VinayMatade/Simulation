import asyncio
from mavsdk import System
from mavsdk.offboard import OffboardError, VelocityNedYaw

async def run():
    drone = System()
    await drone.connect(system_address="udp://:14540")

    print("Waiting for drone to connect...")
    async for state in drone.core.connection_state():
        if state.is_connected:
            print("Drone connected!")
            break

    print("Arming and takeoff...")
    await drone.action.set_takeoff_altitude(5.0)
    await drone.action.arm()
    await asyncio.sleep(1)
    await drone.action.takeoff()
    await asyncio.sleep(6)

    print("Setting initial offboard velocity...")
    try:
        await drone.offboard.set_velocity_ned(VelocityNedYaw(0.0, 0.0, 0.0, 0.0))
        await drone.offboard.start()
        print("Offboard mode started!")
    except OffboardError as e:
        print(f"[ERROR] Failed to start offboard: {e}")
        await drone.action.disarm()
        return

    print("Starting boustrophedon path...")
    await boustrophedon_path(drone, legs=4, length=10, spacing=3, speed=1)

    print("Path complete. Returning to launch.")
    await drone.offboard.stop()
    await asyncio.sleep(1)
    await drone.action.return_to_launch()

async def move_forward(drone, duration, speed, yaw_deg):
    print(f"Moving at speed={speed} m/s, yaw={yaw_deg} deg for {duration} sec")
    await drone.offboard.set_velocity_ned(VelocityNedYaw(speed, 0, 0, yaw_deg))
    await asyncio.sleep(duration)
    await drone.offboard.set_velocity_ned(VelocityNedYaw(0, 0, 0, yaw_deg))
    await asyncio.sleep(1)

async def turn_to(drone, yaw_deg):
    print(f"Turning to yaw={yaw_deg}")
    await drone.offboard.set_velocity_ned(VelocityNedYaw(0, 0, 0, yaw_deg))
    await asyncio.sleep(2)

async def boustrophedon_path(drone, legs, length, spacing, speed):
    yaw_forward = 0
    yaw_reverse = 180

    for i in range(legs):
        forward = i % 2 == 0
        yaw = yaw_forward if forward else yaw_reverse
        print(f"\n[Leg {i+1}/{legs}] {'Forward' if forward else 'Backward'} pass")
        await turn_to(drone, yaw)
        await move_forward(drone, duration=length, speed=(speed if forward else -speed), yaw_deg=yaw)

        if i < legs - 1:
            print("Shifting sideways to next leg...")
            await turn_to(drone, 90)
            await move_forward(drone, duration=spacing, speed=speed, yaw_deg=90)

if __name__ == "__main__":
    asyncio.run(run())
