# HAProxy Dynamic Port Manager

A lightweight, efficient bash script that automatically detects active ports on a local machine and dynamically configures HAProxy to forward traffic to these ports.

## Overview

This tool continuously scans a specified port range on the local machine, detects active ports, and automatically updates HAProxy configuration to create frontend-backend pairs for each active port. It's particularly useful for:

- Dynamic service discovery in development environments
- Auto-configuring reverse proxies for ephemeral services
- Dynamic port forwarding with support for PROXY protocol
- Any scenario where services come online with unpredictable port assignments

## Features

- Fast, efficient port scanning using nmap
- Real-time detection of new active ports
- Automatic HAProxy configuration generation and reloading
- Minimal resource footprint
- Configurable scan intervals for new and existing ports
- Support for transparent proxying and PROXY protocol

## Requirements

- Linux environment with bash
- HAProxy installed and configured
- nmap for port scanning
- Root or sudo privileges (to modify HAProxy config)

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/ajarmoszuk/haproxy-dynamic-port-manager.git
   cd haproxy-dynamic-port-manager
   ```

2. Make the script executable:
   ```bash
   chmod +x haproxy_port_manager.sh
   ```

3. Adjust configuration variables in the script to match your environment:
   - `START_PORT` and `END_PORT`: The port range to monitor
   - `PRIVATE_IP`: The IP address to forward traffic to
   - `CONFIG_FILE`: Path to your HAProxy configuration file
   - `CHECK_INTERVAL_NEW` and `CHECK_INTERVAL_ACTIVE`: Scan intervals

## Usage

Run the script with root privileges:

```bash
sudo ./haproxy_port_manager.sh
```

For production use, you might want to set up a systemd service:

```bash
sudo nano /etc/systemd/system/haproxy-port-manager.service
```

Add the following content:

```
[Unit]
Description=HAProxy Dynamic Port Manager
After=network.target haproxy.service

[Service]
Type=simple
ExecStart=/path/to/haproxy_port_manager.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Then enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable haproxy-port-manager
sudo systemctl start haproxy-port-manager
```

## How It Works

1. The script uses nmap to scan the configured port range on the local machine
2. When an active port is detected, it generates a new HAProxy configuration with frontend-backend pairs
3. The script validates the new configuration and reloads HAProxy
4. This process repeats based on the configured check intervals

## Configuration Options

Edit the variables at the top of the script to customize behavior:

```bash
START_PORT=25566         # Beginning of port range to scan
END_PORT=45566           # End of port range to scan
PRIVATE_IP=127.0.0.1     # IP address to forward traffic to
CONFIG_FILE="/etc/haproxy/haproxy.cfg"  # HAProxy config location
CHECK_INTERVAL_NEW=10    # Check for new ports every 10 seconds
CHECK_INTERVAL_ACTIVE=60 # Re-check active ports every 60 seconds
```

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request 