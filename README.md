<h1 align=center>Zebrafish</h1>

<div align="center">
 <img src="./images/zebrafish.svg" alt="Zebrafish logo" height="200px" />
</div>
<p align="center">
  An immutable OCI container runtime operating system.
</p>

## Key Features

Zebrafish is a modern, security-focused, and containerized operating system designed for reliability and performance. It leverages cutting-edge technologies to provide a robust platform for running containerized applications.

### Containerization

- **Containerd:** Zebrafish uses `containerd` as its container runtime, providing a stable and efficient environment for running OCI-compliant containers.
- **Minimalist Approach:** The OS is designed to be lightweight, shipping only the necessary libraries and tools to run containerized workloads. This reduces the attack surface and improves security.

### Data Integrity and Recovery

- **ZFS File System:** Zebrafish is built on top of the ZFS file system, which provides strong data integrity and protection against data corruption.
- **Disaster Recovery:** The OS includes a built-in mechanism to automatically sync all data with a remote server. This ensures that your data is always backed up and can be easily recovered in case of a disaster.

### Security First

- **Immutability:** The core operating system is immutable, meaning that it cannot be modified at runtime. This prevents unauthorized changes and ensures that the system is always in a known good state.
- **Port Knocking:** Zebrafish supports port knocking, a technique used to hide network ports from unauthorized users. This adds an extra layer of security to your applications.
- **DNS over HTTPS (DoH):** All DNS queries are encrypted and sent over HTTPS, preventing eavesdropping and man-in-the-middle attacks.
- **HTTP/3:** Zebrafish uses HTTP/3 by default, providing a faster and more secure web experience.

### Configuration Management

- **Overlay File System:** Configuration changes can be made through an overlay file system, which stores only the modified files. This makes it easy to manage and track changes to the system.
- **Centralized Updates:** All updates can be tested centrally before being deployed to production, ensuring that your systems are always up-to-date and secure.

## Getting Started

To get started with Zebrafish, you will need to build the OS from source. The following steps will guide you through the process:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/zebrafish.git
   ```
2. **Configure the build:**
   ```bash
   make menuconfig
   ```
3. **Build the OS:**
   ```bash
   make
   ```
4. **Run the OS:**
   ```bash
   qemu-system-x86_64 -M pc -kernel output/images/bzImage -hda output/images/rootfs.ext4 -append "root=/dev/sda"
   ```

## Contributing

Contributions are welcome! If you would like to contribute to Zebrafish, please fork the repository and submit a pull request.

## License

Zebrafish is licensed under the MIT License. See the `LICENSE` file for more information.