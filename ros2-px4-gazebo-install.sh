#!/usr/bin/env bash
#
# =============================================================================
#
# Title:          Automated ROS2 Humble & PX4-Autopilot Setup Script
# Description:    This script automates the complete installation of a ROS2
#                 and PX4 development environment for SITL simulation.
#                 It handles dependencies, installs required software, and
#                 builds the necessary workspaces.
#
# Author:         Vinay Matade
#
# =============================================================================

# ---
# Section 1: Strict Mode and Error Handling
#
# set -Eeuo pipefail: This is the "unofficial strict mode" for Bash.
#
# -E (errtrace): Ensures the ERR trap is inherited by functions and subshells.
# -e (errexit): Exits immediately if a command fails.
# -u (nounset): Treats unset variables as an error and exits.
# -o pipefail: Causes a pipeline to fail if any command within it fails.
#
set -Eeuo pipefail

# ---
# Section 2: Robust Logging with Color Support
#
# These functions provide leveled and colored logging to make script output
# clear and easy to read. It checks if the terminal supports colors.
#
setup_colors() {
  # Only use colors if connected to a terminal
  if [ -t 1 ]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    BOLD=$(tput bold)
    NC=$(tput sgr0) # No Color
  else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    BOLD=""
    NC=""
  fi
}

log_info() {
  echo -e "${BLUE}${BOLD}INFO:${NC} $1"
}

log_success() {
  echo -e "${GREEN}${BOLD}SUCCESS:${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}${BOLD}WARN:${NC} $1"
}

log_error() {
  # Direct error messages to stderr
  echo -e "${RED}${BOLD}ERROR:${NC} $1" >&2
}

# ---
# Section 3: Core Logic Functions
#
# Each major step of the installation is encapsulated in its own function.
#

# Validates the Python installation and version.
check_python_version() {
  log_info "Validating Python 3.10.x installation..."

  if! command -v python3 &>/dev/null; then
    log_error "python3 is not installed or not found in PATH. Please install Python 3.10.11"
    exit 1
  fi

  # Capture version string, redirecting stderr to stdout as version info is often on stderr.[1]
  local version_string
  version_string="$(python3 --version 2>&1)"

  # Parse the version number from the string (e.g., "Python 3.10.4" -> "3.10.4").[1]
  local python_version
  python_version="$(echo "$version_string" | awk '{print $2}')"

  if [[ -z "$python_version" ]]; then
    log_error "Could not parse version from Python output: '$version_string'"
    exit 1
  fi

  # Check if the version starts with "3.10"
  if [[ "$python_version" == "3.10" || "$python_version" == "3.10."* ]]; then
    log_success "Python version is confirmed to be 3.10.x (found: $python_version)."
  else
    log_error "Required Python version is 3.10.x, but found $python_version."
    exit 1
  fi
}

# Installs ROS2 Humble and its development tools.
install_ros2() {
  log_info "Setting up ROS2 Humble..."
  # Check if ROS2 is already installed to avoid re-running setup
  if [ -d "/opt/ros/humble" ]; then
    log_warn "ROS2 Humble installation found at /opt/ros/humble. Skipping installation."
    return
  fi

  log_info "Updating package lists and installing prerequisites..."
  sudo apt-get update
  sudo apt-get install -y software-properties-common locales curl

  log_info "Setting locale..."
  sudo locale-gen en_US en_US.UTF-8
  sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

  log_info "Adding ROS2 apt repository..."
  sudo add-apt-repository universe -y
  sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

  log_info "Installing ROS2 Humble Desktop, development tools, and Python dependencies..."
  sudo apt-get update
  sudo apt-get install -y \
    ros-humble-desktop \
    ros-dev-tools \
    python3-pip \
    python3-flake8-docstrings \
    python3-pytest-cov \
    python3-flake8-blind-except \
    python3-flake8-builtins \
    python3-flake8-class-newline \
    python3-flake8-comprehensions \
    python3-flake8-deprecated \
    python3-flake8-import-order \
    python3-flake8-quotes \
    python3-pytest-repeat \
    python3-pytest-rerunfailures

  log_info "Sourcing ROS2 and adding to.bashrc..."
  # Source for the current script session
  # shellcheck source=/dev/null
  source /opt/ros/humble/setup.bash
  # Add to.bashrc for future terminal sessions
  if! grep -q "source /opt/ros/humble/setup.bash" ~/.bashrc; then
    echo "source /opt/ros/humble/setup.bash" >>~/.bashrc
  fi

  log_info "Installing Python dependencies for ROS2 via pip..."
  pip3 install --user -U empy pyros-genmsg setuptools==59.6.0

  log_success "ROS2 Humble installation complete."
}

# Clones and sets up the PX4-Autopilot firmware.
install_px4_autopilot() {
  log_info "Setting up PX4-Autopilot..."
  if [ -d "$HOME/PX4-Autopilot" ]; then
    log_warn "PX4-Autopilot directory already exists. Skipping clone."
  else
    log_info "Cloning PX4-Autopilot repository (this may take a while)..."
    git clone https://github.com/PX4/PX4-Autopilot.git --recursive "$HOME/PX4-Autopilot"
  fi

  log_info "Running the PX4 dependency installation script..."
  sudo bash "$HOME/PX4-Autopilot/Tools/setup/ubuntu.sh"
  make px4_sitl

  log_success "PX4-Autopilot setup is complete."
}

# Installs the Micro XRCE-DDS Agent required for PX4-ROS2 communication.
install_xrce_dds_agent() {
  log_info "Setting up Micro XRCE-DDS Agent..."
  if command -v MicroXRCEAgent &>/dev/null; then
    log_warn "MicroXRCEAgent command already found. Skipping installation."
    return
  fi

  if [ -d "$HOME/Micro-XRCE-DDS-Agent" ]; then
    log_warn "Micro-XRCE-DDS-Agent directory already exists. Skipping clone."
  else
    log_info "Cloning Micro-XRCE-DDS-Agent repository..."
    git clone https://github.com/eProsima/Micro-XRCE-DDS-Agent.git "$HOME/Micro-XRCE-DDS-Agent"
  fi

  log_info "Building and installing the agent..."
  pushd "$HOME/Micro-XRCE-DDS-Agent"
  mkdir -p build
  cd build
  cmake..
  make
  sudo make install
  sudo ldconfig /usr/local/lib/
  popd

  log_success "Micro XRCE-DDS Agent installed successfully."
}

# Creates and builds the ROS2 workspace with PX4 messages and communication packages.
setup_ros2_workspace() {
  local ws_path="$HOME/ros2_humble"
  log_info "Setting up ROS2 workspace at ${ws_path}..."

  mkdir -p "${ws_path}/src"
  pushd "${ws_path}/src"

  if [ -d "px4_msgs" ]; then
    log_warn "'px4_msgs' package already exists. Skipping clone."
  else
    log_info "Cloning px4_msgs..."
    git clone https://github.com/PX4/px4_msgs.git
  fi

  if [ -d "px4_ros_com" ]; then
    log_warn "'px4_ros_com' package already exists. Skipping clone."
  else
    log_info "Cloning px4_ros_com..."
    git clone https://github.com/PX4/px4_ros_com.git
  fi

  popd # return to ws_path

  # Source ROS2 environment to make colcon and other tools available
  # shellcheck source=/dev/null
  source /opt/ros/humble/setup.bash
  colcon build --symlink-install

  log_success "ROS2 workspace built successfully."
}

# Prints the final instructions for running the simulation.
print_run_instructions() {
  log_info "Your ROS2-PX4 environment is now fully configured."
  echo -e "\nTo run a simulation, you need to open ${BOLD}4 separate terminals${NC} and run the following commands:"
  echo -e "\n${GREEN}--- Terminal 1: Start the Micro XRCE-DDS Agent ---${NC}"
  echo -e "MicroXRCEAgent udp4 -p 8888"

  echo -e "\n${GREEN}--- Terminal 2: Start the PX4 SITL Simulation ---${NC}"
  echo -e "cd ~/PX4-Autopilot"
  echo -e "make px4_sitl gz_x500"

  echo -e "\n${GREEN}--- Terminal 3: Run a ROS2 Example Node ---${NC}"
  echo -e "cd ~/ros2_px4_ws"
  echo -e "source install/setup.bash"
  echo -e "ros2 launch px4_ros_com sensor_combined_listener.launch.py"
  echo -e "\n"

  echo -e "${GREEN}--- Terminal 4: Run QGroundControl ---${NC}"
}

# ---
# Section 4: Main Execution Logic
#
main() {
  # Setup logging and traps first.
  setup_colors
  trap 'log_error "An error occurred. Aborting script at line $LINENO."; exit 1' ERR
  trap 'log_info "Script execution finished."' EXIT

  log_info "Starting ROS2-PX4 Installation Script..."

  # --- Execute setup steps ---
  check_python_version
  install_ros2
  install_px4_autopilot
  install_xrce_dds_agent
  setup_ros2_workspace
  print_run_instructions

  log_success "All setup steps completed successfully!"
}

# ---
# Script Entry Point
#
main "$@"
