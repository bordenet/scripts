# Malware Analysis Sandbox

This project provides a script to create a secure, isolated sandbox environment for analyzing potentially malicious files on macOS.

## Features

- **Automated Setup:** A single script to set up the entire environment.
- **Isolated Environment:** The sandbox is a virtual machine with no network access, preventing any potential malware from affecting your host machine or network.
- **Read-Only File Sharing:** A read-only shared directory is used to get files into the sandbox, preventing malware from writing back to your host machine.
- **Analysis Tools:** The sandbox comes with a script to install common analysis tools like ClamAV, `file`, `strings`, and `hexedit`.
- **Reproducible:** The environment can be destroyed and recreated on demand.

## Prerequisites

- [Homebrew](https://brew.sh/)
- [UTM](https://mac.getutm.app/)

## Manual VM Creation

Before running the script, you need to manually create a new virtual machine in the UTM app.

2.  **Create a new VM:**
    - Open UTM and click the "+" button to create a new virtual machine.
    - Select "Emulate".
    - Select "Linux".
    - For the "Architecture", select "Intel x86_64", 2048 MiB of RAM, and 2 CPU cores.
    - For the "Boot ISO Image", select the `alpine.iso` file that was downloaded by the setup script.
    - For "Storage" select "New Drive", set the size to `8 GiB`, and leave the other settings as default.
    - For "Shared Directory", click "Browse...", and choose the `shared` directory inside the `inspection-sandbox` directory. Set the mode to "Read-Only".
    - On the "Summary" page, set the name of the VM to `inspection-sandbox`.
    - Click "Save" to create the VM.
3.  **Configure the VM:**
    - Once the VM is created, select it and click the "Edit" button -- the control-panel icon in the top-right corner of the screen.
        - **Network:**
            - Set the "Network Mode" to "Emulated VLAN".
            - Check the box for "Show Advanced Settings" and then check the box for "Isolate Guest from Host".
            - Click the "Save" button.
        - **Network - Port Forwarding:**
            - Note the presence of a "Port Forwarding" option under Network in the left-hand nav. Click it.
            - Click the "New..." button.
    - **Port Forward:**
        - Click "New..."
        - **Protocol:** Leave as "TCP".
        - **Guest IP:** Leave blank.
        - **Guest Port:** Set to `22`.
        - **Host IP:** Set to `127.0.0.1`.
        - **Host Port:** Set to `2222`.
        - Click "Save".
    - **Sharing:**
        - Click on the Edit button again to return to the main settings menu.
        - Click on "Sharing" in the left-hand nav.
        - *Uncheck* "Enable Clipboard Sharing". This is a security vulnerability.
        - Ensure that the Directory Share Mode is set to "VirtFS"
        - Ensure that the "Mode" is set to _"Read-Only"_.
        - Click "Save".
4.  **Install Alpine Linux:**
    - Start the VM.
    - At the GRUB menu, select "Linux lts" to boot into the Alpine Linux installer.
    - At the login prompt, type `root`.
    - Run `setup-alpine` and follow the prompts.
    - When asked to choose a password, set a password for the `root` user.
    - When asked to choose a disk, choose `sda`.
    - When asked to choose how to use it, choose `sys`.
    - After the installation is complete, run `rc-update add sshd` to enable the SSH server. You can safely ignore the message "rc-update: sshd already installed in runlevel `default'; skipping".
    - Run `echo "PermitRootLogin yes" >> /etc/ssh/sshd_config` to allow root login.
    - Run `echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config` to enable key-based authentication.
    - After the installation is complete, power off the VM.

## How to Use

The `setup_sandbox.sh` script is used to manage the sandbox environment.

### Setup

To set up the sandbox environment, run the script with no arguments:

```bash
./setup_sandbox.sh
```

This will:

1.  Check for dependencies.
2.  Create the `shared` directory.
3.  Generate an SSH key pair.
4.  Copy the public key to the `shared` directory.

### Test the Sandbox

To test the sandbox, run the script with the `test` argument:

```bash
./setup_sandbox.sh test
```

This will:

1.  Create a test file in the shared directory.
2.  Start the VM.
3.  Run the `analyze.sh` script inside the VM to scan the test file.
4.  Stop the VM.

### Destroy the Sandbox

To destroy the sandbox, run the script with the `burn` argument:

```bash
./setup_sandbox.sh burn
```

This will:

1.  Stop the VM if it's running.
2.  Delete the VM.
3.  Remove all files and directories created by the script.

## Using the Sandbox

### Getting Files into the Sandbox

To get files into the sandbox, simply copy them to the `shared` directory. This directory is mounted as a read-only directory at `/media/shared` inside the VM.

### Analyzing Files

To analyze files, start the VM:

```bash
utmctl start inspection-sandbox
```

Then, SSH into the VM:

```bash
ssh -i id_rsa -p 2222 root@localhost
```

Once you are in the VM, you can use the `analyze.sh` script to install tools and scan files.

To install the analysis tools, run:

```bash
/media/shared/analyze.sh install-tools
```

To scan a file, run:

```bash
/media/shared/analyze.sh scan /media/shared/your_file_to_scan
```

## Future Enhancements

- **GUI Support:** Add a lightweight desktop environment (like XFCE) and a file manager to allow for visual inspection of files.
- **Network Analysis:** Add tools like `tcpdump` and `wireshark` and configure a virtual network to analyze network traffic from malware.
- **Automated Reporting:** Add a feature to generate a report of the analysis, including the output of the various tools.
- **Snapshotting:** Add a feature to take snapshots of the VM so you can revert to a clean state after an analysis.
- **Different Linux Distributions:** Add support for other Linux distributions, such as Debian or Ubuntu.
- **Windows Support:** Add support for creating a Windows sandbox.
