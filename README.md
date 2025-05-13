
# Neverminer - HiveOs Miner

## :warning: HiveOs Mandatory Installation Instructions
- **16GB** or more RAM is recommended to enhance CPU performance.
- **Higher RAM frequencies** contribute to better CPU performance.
- **Avoid overloading** your CPU with threads; instead, aim to find the optimal balance.

- To run the Qubic miner, you need the latest stable version of HiveOS.
```sh
hive-replace --stable --yes
```

<br/>

### **⚙️ NVIDIA GPU Requirements:**
> [!NOTE]
> To update your NVIDIA GPU driver on HiveOS, please run the following command:
```sh
nvidia-driver-update
```
- **NVIDIA 3000 Series:** Driver version **535+** or newer.
- **NVIDIA 4000 Series:** Driver version **550+**.

<!--

### **⚙️ AMD GPU Requirements:**
> [!NOTE]
> AMD support may not be available all the time; availability depends on the epoch.

- Install version 5.7.3 driver using the command:
```sh
amd-ocl-install 5.7 5.7
```
- Install the libamdhip64 library. 
Run the following commands:
```sh
cd /opt/rocm/lib && wget https://github.com/Gddrig/Qubic_Hiveos/releases/download/0.4.1/libamdhip64.so.zip && unzip libamdhip64.so.zip && chmod +rwx /opt/rocm/lib/* && rm libamdhip64.so.zip && cd / && ldconfig
```

-->
<br>

## ✈️ Flight Sheet Configuration

- **Miner name:** Automatically filled with the installation URL.
- **Installation URL:** `https://github.com/hackerby888/neverminer-hiveos/releases/download/3.3.4/neverminer-latest.tar.gz`
- **Hash algorithm:** Not used, leave as `----`.
- **Wallet and worker template:** `%WORKER_NAME%`. 
- **Pool URL:** Use `ws://qubic.nevermine.io/ws`.
- **Pass:** Not used.
- **Extra config arguments**: `"wallet": YOUR_QUBIC_WALLET`
  

### 🔨 GPU+CPU (Dual) mining:
![Flight Sheet Dual](/img/FlightSheetDual.png)
<br>
> [!NOTE]
>"amountOfThreads":0 will use all available threads minus one.
> 
**Extra Config Arguments Example:**
```
"wallet": YOUR_QUBIC_WALLET
"amountOfThreads":0
```

### 🔨 GPU mining:
![Flight Sheet GPU](/img/FlightSheetGPU.png)
<br>
**Extra Config Arguments Example:**
```
"wallet": YOUR_QUBIC_WALLET
```
<!--
