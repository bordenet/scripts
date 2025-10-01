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

1.  **Download Alpine Linux:** Download the "Standard" x86_64 image from the [Alpine Linux downloads page](https://alpinelinux.org/downloads/).
2.  **Create a new VM:**
    - Open UTM and click the "+" button to create a new virtual machine.
    - Select "Virtualize".
    - Select "Linux".
    - For the "Boot ISO Image", select the Alpine Linux ISO you downloaded.
    - Click "Continue" and accept the defaults for the rest of the setup.
3.  **Configure the VM:**
    - Once the VM is created, select it and click the "Edit" button.
    - **Name:** Set the name to `malware-inspector`.
    - **Memory:** Set the memory to 2048 MB.
    - **CPUs:** Set the CPUs to 2.
    - **Network:**
        - Set the "Network Mode" to "Isolated".
        - Add a new port forward: `tcp:2222:22`.
    - **Sharing:**
        - Set the "Shared Directory" to the `shared` directory inside the `inspection-sandbox` directory.
        - Set the "Mode" to "Read-Only".
4.  **Install Alpine Linux:**
    - Start the VM.
    - At the login prompt, type `root`.
    - Run `setup-alpine` and follow the prompts.
    - When asked to choose a disk, choose `vda`.
    - When asked to choose how to use it, choose `sys`.
    - When asked to choose a password, set a password for the `root` user.
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
utmctl start malware-inspector
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
