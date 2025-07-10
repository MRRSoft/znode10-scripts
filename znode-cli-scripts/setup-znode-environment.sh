#!/bin/bash



# A comprehensive script to install the Znode CLI and all its dependencies on Ubuntu.

# This script is idempotent, meaning it can be run multiple times without causing issues.



# --- Style and Helper Functions ---

# Use color codes for better user feedback

BLUE='\033[0;34m'

GREEN='\033[0;32m'

YELLOW='\033[1;33m'

RED='\033[0;31m'

NC='\033[0m' # No Color



info() {

echo -e "${BLUE}INFO:${NC} $1"

}



success() {

echo -e "${GREEN}SUCCESS:${NC} $1"

}



warn() {

echo -e "${YELLOW}WARNING:${NC} $1"

}



error() {

echo -e "${RED}ERROR:${NC} $1" >&2

exit 1

}



# This function stops the script if a command fails

set -e

# <<< START: ADDED CODE >>>
# Function to handle Ctrl+C
handle_ctrl_c() {
    echo -e "\n\n${RED}USER ABORTED:${NC} Script execution cancelled."
    exit 130 # Exit with a standard code for interruption
}

# Set a trap for the SIGINT signal (Ctrl+C)
trap handle_ctrl_c SIGINT
# <<< END: ADDED CODE >>>

# --- Main Script ---



clear

echo -e "${BLUE}=====================================================${NC}"

echo -e "${BLUE} Znode CLI and Environment Setup for Ubuntu ${NC}"

echo -e "${BLUE}=====================================================${NC}"

echo

info "This script will guide you through the complete setup process."

echo "Here is a summary of what we are about to do:"

echo

echo -e " 1. ${YELLOW}Install Essential Tools:${NC} Install 'curl', 'jq', 'wget', and 'apt-transport-https' if they are missing."

echo -e " 2. ${YELLOW}Increase System Limits:${NC} Modify system files to increase 'inotify' and 'file descriptor' limits. This prevents crashes in Znode applications."

echo -e " 3. ${YELLOW}Install .NET 8 SDK:${NC} The core runtime required to execute the Znode CLI."

echo -e " 4. ${YELLOW}Install SQL Server Tools:${NC} Install 'sqlcmd' for database command-line interaction."

echo -e " 5. ${YELLOW}Install SQLPackage Tool:${NC} Install 'Microsoft.SqlPackage', a database tool used by the Znode CLI."

echo -e " 6. ${YELLOW}Install Znode CLI:${NC} Install the main Znode command-line tool from a private NuGet feed."

echo -e " 7. ${YELLOW}Configure Environment:${NC} Update the PATH in your '.bashrc' to make all new tools accessible from anywhere."

echo

warn "This script needs to use 'sudo' to install software and modify system configuration files."

warn "You will be prompted to enter your password when 'sudo' is required."

echo



# --- User Confirmation ---

# If -y or --yes flag is passed, skip confirmation.

if [[ "$1" == "-y" || "$1" == "--yes" ]]; then

info "'-y' flag detected. Proceeding with automatic setup."

else

read -p "Do you want to proceed with the setup? (y/N): " -n 1 -r

echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then

echo "Setup cancelled by the user."

exit 1

fi

fi

echo



# --- 1. Install Essential Tools ---

info "Step 1: Checking for and installing essential tools (curl, jq, etc.)."

info "Why? These tools are required to download software packages and handle data during the setup."

sudo apt-get update -qq

sudo apt-get install -y curl jq wget apt-transport-https > /dev/null

success "Essential tools are installed and up to date."

echo



# --- 2. Increase System Limits ---

info "Step 2: Increasing system limits for file descriptors and inotify watches."

info "Why? Servers monitor many files. The default Linux limits are often too low, which can cause applications to crash. This change makes the system more robust."



# Inotify limit

if ! grep -q "fs.inotify.max_user_watches=524288" /etc/sysctl.conf; then

info "Setting permanent inotify limits in /etc/sysctl.conf..."

echo 'fs.inotify.max_user_watches=524288' | sudo tee -a /etc/sysctl.conf > /dev/null

echo 'fs.inotify.max_user_instances=8192' | sudo tee -a /etc/sysctl.conf > /dev/null

sudo sysctl -p /etc/sysctl.conf > /dev/null

success "Inotify limits have been increased permanently."

else

success "Inotify limits are already set correctly."

fi



# File descriptor limit

if ! grep -q "* soft nofile 65536" /etc/security/limits.conf; then

info "Setting file descriptor limits in /etc/security/limits.conf..."

echo '* soft nofile 65536' | sudo tee -a /etc/security/limits.conf > /dev/null

echo '* hard nofile 65536' | sudo tee -a /etc/security/limits.conf > /dev/null

if ! grep -q "session required pam_limits.so" /etc/pam.d/common-session; then

echo 'session required pam_limits.so' | sudo tee -a /etc/pam.d/common-session > /dev/null

fi

success "File descriptor limits have been increased."

warn "A system reboot or logout/login is required for file descriptor limit changes to take full effect."

else

success "File descriptor limits are already set correctly."

fi

echo



# --- 3. Install .NET 8 SDK ---

info "Step 3: Checking for and installing the .NET 8 SDK."

info "Why? The Znode CLI is a .NET application and requires the .NET SDK to run."

if command -v dotnet &> /dev/null && dotnet --list-sdks | grep -q "^8\."; then

success ".NET SDK 8.x is already installed. Version: $(dotnet --version)"

else

info "Installing .NET 8 SDK..."

# Add Microsoft package repository

wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb

sudo dpkg -i packages-microsoft-prod.deb > /dev/null

rm packages-microsoft-prod.deb


# Install .NET SDK

sudo apt-get update -qq

sudo apt-get install -y dotnet-sdk-8.0 > /dev/null

success ".NET SDK 8.0 installation completed. Version: $(dotnet --version)"

fi

echo



# --- 4. Install SQL Server Tools (sqlcmd) ---

info "Step 4: Checking for and installing SQL Server command-line tools (sqlcmd)."

info "Why? 'sqlcmd' is a utility used for interacting with SQL Server databases from the command line."

if ! command -v sqlcmd &> /dev/null; then

info "Installing 'sqlcmd'..."

if ! curl -sS https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc > /dev/null; then

error "Failed to add Microsoft GPG key for sqlcmd."

fi

if ! curl -sS https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list > /dev/null; then

error "Failed to register Microsoft repository for sqlcmd."

fi



sudo apt-get update -qq

info "Installing mssql-tools18... This requires accepting an EULA."

if ! sudo ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev > /dev/null; then

error "Failed to install mssql-tools18. Please try installing it manually."

fi

success "'sqlcmd' has been installed."

else

success "'sqlcmd' is already installed."

fi

echo



# --- 7. Configure Environment PATH (Done here to ensure tools are found) ---

info "Step 5: Updating PATH for all tools."

info "Why? The PATH variable tells your terminal where to find executable programs. We need to add the directories for .NET tools and sqlcmd so you can run them from anywhere."



# Add .NET tools to PATH

if ! grep -q 'export PATH="$PATH:$HOME/.dotnet/tools"' "$HOME/.bashrc"; then

info "Adding .NET tools directory to your .bashrc PATH."

echo '' >> "$HOME/.bashrc"

echo '# Add .NET Core SDK tools to PATH' >> "$HOME/.bashrc"

echo 'export PATH="$PATH:$HOME/.dotnet/tools"' >> "$HOME/.bashrc"

success ".NET tools PATH added to .bashrc."

else

success ".NET tools PATH is already in .bashrc."

fi



# Add mssql-tools to PATH

if ! grep -q 'export PATH="$PATH:/opt/mssql-tools18/bin"' "$HOME/.bashrc"; then

info "Adding mssql-tools directory to your .bashrc PATH."

echo '' >> "$HOME/.bashrc"

echo '# Add MS SQL Server tools to PATH' >> "$HOME/.bashrc"

echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> "$HOME/.bashrc"

success "mssql-tools PATH added to .bashrc."

else

success "mssql-tools PATH is already in .bashrc."

fi



# Apply PATH changes to the current session

export PATH="$PATH:$HOME/.dotnet/tools:/opt/mssql-tools18/bin"

echo



# --- 5. Install SQLPackage ---

info "Step 6: Checking for and installing Microsoft.SqlPackage."

info "Why? 'sqlpackage' is a database utility required for specific Znode CLI database operations."

if ! command -v sqlpackage &> /dev/null; then

info "Installing 'Microsoft.SqlPackage' as a .NET global tool..."

dotnet tool install --global Microsoft.SqlPackage > /dev/null

success "'Microsoft.SqlPackage' installed successfully."

else

success "'Microsoft.SqlPackage' is already installed."

fi

echo



# --- 6. Install Znode CLI ---

info "Step 7: Installing the Znode CLI."

info "Why? This is the primary tool this script is designed to set up."

warn "To download the Znode CLI, you must provide credentials for the private Znode NuGet feed."



while [[ -z "$ZNODE_NUGET_USER" ]]; do

read -p "Enter your Znode NuGet Username: " ZNODE_NUGET_USER

if [[ -z "$ZNODE_NUGET_USER" ]]; then

echo -e "${RED}Username cannot be empty. Please try again.${NC}"

fi

done



while [[ -z "$ZNODE_NUGET_PASS" ]]; do

read -sp "Enter your Znode NuGet Password: " ZNODE_NUGET_PASS

echo

if [[ -z "$ZNODE_NUGET_PASS" ]]; then

echo -e "${RED}Password cannot be empty. Please try again.${NC}"

fi

done

#Setting znode nuget source to the value passed by user if not then default to the production source
ZNODE_NUGET_SOURCE={$ZNODE_NUGET_SOURCE:-"https://nuget.znode.com/nuget"}

info "Configuring NuGet sources and installing/updating the Znode CLI..."

# Remove old source to avoid conflicts and ensure credentials are correct

dotnet nuget remove source "NugetZnode10xCLI" > /dev/null 2>&1 || true

# Add the authenticated Znode source

dotnet nuget add source "$ZNODE_NUGET_SOURCE" -n "NugetZnode10xCLI" -u "$ZNODE_NUGET_USER" -p "$ZNODE_NUGET_PASS" --store-password-in-clear-text > /dev/null

# Install or update the Znode CLI tool

dotnet tool install --global Znode.CLI > /dev/null

success "Znode CLI tool installed/updated successfully."

echo



# --- Final Verification ---

echo -e "${BLUE}=====================================================${NC}"

echo -e "${GREEN} Setup and Verification Complete! ${NC}"

echo -e "${BLUE}=====================================================${NC}"

echo

info "Verifying final installations:"

echo -n " - .NET SDK Version: " && success "$(dotnet --version)"

echo -n " - sqlcmd path: " && success "$(command -v sqlcmd)"

echo -n " - sqlpackage path: " && success "$(command -v sqlpackage)"

echo -n " - Znode CLI Version: " && success "$(Znode --version)"

echo

warn "Please run 'source ~/.bashrc' or open a new terminal for all changes to be applied."

warn "A full system reboot is recommended to ensure the file descriptor limit changes take effect."

echo
