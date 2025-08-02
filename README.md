# ROS 2 Humble & PX4 SITL Simulation Environment

This guide provides complete instructions for using a development environment for ROS 2 Humble with PX4 Software-in-the-Loop (SITL) simulation using Gazebo. This setup is intended for offboard control development and testing.

<br>

## Table of Contents
1.  [Overview](#overview)
2.  [Prerequisites](#prerequisites)
3.  [Installation](#installation)
4.  [Component Overview](#component-overview)
5.  [Running the Simulation](#running-the-simulation)
6.  [Running an Offboard Example](#running-an-offboard-example)

---
## Overview

This environment, set up by the accompanying installation script, contains all the necessary components for developing and testing autonomous drone applications. It combines the powerful ROS 2 robotics framework with the professional-grade PX4 flight control software in a simulated 3D world.

---
## Prerequisites

Before running the installation script, ensure your system meets the following requirements:

* **Operating System**: Ubuntu 22.04 (Jammy Jellyfish).
* **Permissions**: You must have `sudo` privileges.

### Python Version Check

This installation **critically depends** on having **Python 3.10.x**. ROS 2 Humble and its tools are built specifically against this version. The provided installation script will check your Python version and fail if it is incorrect.

To check your version manually, run:
```bash
python3 --version
```

---
## Installation

All the required software and dependencies are installed automatically by running the `ros2-px4-install.sh` script. This script handles the entire setup process, from installing system packages to cloning and building the required software.
Run this in the repository directory to install.
```bash 
chmod +x ./ros2-px4-install.sh
sudo ./ros2-px4-install.sh
```

---
## Component Overview

The installation script sets up the following key components:

* **ROS 2 Humble Hawksbill**: The core robotics middleware. The script installs the `ros-humble-desktop` version, which includes Gazebo, Rviz, and other essential GUI tools.
* **Gazebo**: A 3D robotics simulator used to create a realistic environment for testing the drone's control algorithms without physical hardware.
* **PX4-Autopilot**: The flight control software that runs in Software-in-the-Loop (SITL) mode. This allows the real flight code to be tested on your computer.
    * **Directory**: `~/PX4_Autopilot`
* **Micro XRCE-DDS Agent**: The bridge that enables communication between ROS 2 and the PX4 Autopilot. It translates ROS 2 messages into a protocol that PX4 understands (uORB), and vice-versa.
    * **Directory**: `~/Micro-XRCE-DDS-Agent`
* **ROS 2 Workspace (`~/ros2_humble`)**: This workspace contains the specific ROS 2 packages needed to communicate with PX4.
    * `px4_msgs`: Contains the ROS 2 message definitions that correspond to PX4's internal topics. This allows ROS 2 nodes to understand the data coming from PX4.
    * `px4_ros_com`: Provides the main bridge node, launch files, and examples for offboard control.
* **QGroundControl**: A ground control station application for monitoring and controlling the simulated drone. The script does not install this, but it is highly recommended.
    * **Download**: The recommended version is the AppImage, which runs on most Linux distributions without installation.
        [**Download QGroundControl AppImage Here**](https://docs.qgroundcontrol.com/master/en/getting_started/download_and_install.html)
    * **To run the AppImage**:
        ```bash
        chmod +x ./QGroundControl.AppImage
        ./QGroundControl.AppImage
        ```

---
## Running the Simulation

To start the simulation, you will need to run **three separate commands in three separate terminals**. The order is important.

### Terminal 1: Start the Micro XRCE-DDS Agent

This terminal listens for communication from the PX4 simulator.

```bash
# Source your ROS 2 environment
source /opt/ros/humble/setup.bash

# Start the agent
MicroXRCEAgent udp4 -p 8888
```

### Terminal 2: Start PX4 SITL with Gazebo

This command starts the PX4 flight stack in simulation mode and launches a drone model in the Gazebo 3D environment.

```bash
# Navigate to the PX4 directory
cd ~/PX4_Autopilot

# Start the simulation
make px4_sitl gz_x500
```
You should see Gazebo open with a drone on a runway.

### Terminal 3: Source Your Workspace

This terminal will be used to run your ROS 2 nodes. You must first source your local workspace's setup file to make its packages available.

```bash
# Navigate to your ROS 2 workspace
cd ~/ros2_humble

# Source the overlay workspace
source install/setup.bash
```

---
## Running an Offboard Example

With the simulation running and all three terminals set up, you can now run a ROS 2 node to take control of the drone.

### Run the Offboard Control Node

In **Terminal 3**, run the following command. This node will command the drone to arm, take off to an altitude of 5 meters, and hold its position.

```bash
ros2 run px4_ros_com offboard_control
```

You can observe the drone taking off in the Gazebo window and see its status change in the QGroundControl interface.
