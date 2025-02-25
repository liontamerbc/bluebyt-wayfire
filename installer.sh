# === Backup and Install Configuration Files ===
echo "Backing up existing configuration..."
_backup_dir=~/.config_backup_$(date +%F_%T)
mkdir -p "$_backup_dir"
cp -r ~/.config/* "$_backup_dir/" 2>/dev/null || true

echo "Cloning and setting up configuration files..."
git clone https://github.com/bluebyt/wayfire-dots.git
if [ -d "wayfire-dots/config" ]; then
    cp -r wayfire-dots/config/* ~/.config/
else
    echo "Warning: Configuration directory not found in wayfire-dots. Skipping config setup."
fi

# Handle binaries if bin/ directory exists
if [ -d "wayfire-dots/bin" ]; then
    echo "Setting up binaries in ~/.bin/..."
    mv wayfire-dots/bin wayfire-dots/.bin
    cp -r wayfire-dots/.bin ~/
    # Add ~/.bin to PATH in shell configuration
    if [ -f ~/.bashrc ]; then
        echo 'export PATH="$HOME/.bin:$PATH"' >> ~/.bashrc
    elif [ -f ~/.zshrc ]; then
        echo 'export PATH="$HOME/.bin:$PATH"' >> ~/.zshrc
    elif [ -f ~/.config/fish/config.fish ]; then
        echo 'set -gx PATH $HOME/.bin $PATH' >> ~/.config/fish/config.fish
    fi
    echo "Binaries have been placed in ~/.bin/ and added to your PATH."
fi

if [ -f "wayfire-dots/wayfire.desktop" ]; then
    sudo cp wayfire-dots/wayfire.desktop /usr/share/wayland-sessions/
else
    echo "Warning: wayfire.desktop not found. You may need to configure your login manager manually."
fi
rm -rf wayfire-dots
