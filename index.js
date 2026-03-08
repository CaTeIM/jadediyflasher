const boardsel = document.getElementById("boardsel");
const fwsel = document.getElementById("fwsel");
const connectButton = document.getElementById("connectButton");
const btprogressBar = document.getElementById("bootloaderprogress");
const btprogressBarLbl = document.getElementById("bootloaderprogresslbl");
const otaprogressBar = document.getElementById("otaprogress");
const otaprogressBarLbl = document.getElementById("otaprogresslbl");
const ptprogressBar = document.getElementById("partitiontableprogress");
const ptprogressBarLbl = document.getElementById("partitiontableprogresslbl");
const jadeprogressBar = document.getElementById("jadeprogress");
const jadeprogressBarLbl = document.getElementById("jadeprogresslbl");
const lblboard = document.getElementById("lblboard");
const lblfw = document.getElementById("lblfw");
const flashCountEl = document.getElementById("flashCount");

// Counter API
const COUNTER_NS = "cateim-jadediy";
const COUNTER_KEY = "flash-count";
const COUNTER_URL = `https://api.counterapi.dev/v1/${COUNTER_NS}/${COUNTER_KEY}`;

async function loadFlashCount() {
  try {
    const res = await fetch(COUNTER_URL);
    if (res.ok) {
      const data = await res.json();
      flashCountEl.textContent = data.count.toLocaleString("pt-BR");
    }
  } catch (_) {
    flashCountEl.textContent = "—";
  }
}

async function incrementFlashCount() {
  try {
    const res = await fetch(COUNTER_URL + "/up");
    if (res.ok) {
      const data = await res.json();
      flashCountEl.textContent = data.count.toLocaleString("pt-BR");
    }
  } catch (_) {}
}

loadFlashCount();

import * as esptooljs from "./bundle.js";
const ESPLoader = esptooljs.ESPLoader;
const Transport = esptooljs.Transport;

let device = null;
let transport;
let chip = null;
let esploader;

// Board → available firmware versions (newest first)
const boardFirmwares = {
  tdisplay: ["1.0.39-beta2", "1.0.38-98", "1.0.38"],
  tdisplays3: ["1.0.39-beta2", "1.0.38-98", "1.0.38"],
  waveshares3: ["1.0.39-beta2", "1.0.38-98"],
};

// Board display names
const boardNames = {
  tdisplay: "LILYGO T-Display",
  tdisplays3: "LILYGO T-Display S3",
  waveshares3: "Waveshare S3 Touch LCD 2",
};

// Populate firmware select based on selected board
function updateFirmwareOptions() {
  const board = boardsel.value;
  fwsel.innerHTML = "";

  if (!board) {
    // Board not selected yet — show placeholder
    const placeholder = document.createElement("option");
    placeholder.value = "";
    placeholder.disabled = true;
    placeholder.selected = true;
    placeholder.textContent = "— Selecione o firmware —";
    fwsel.appendChild(placeholder);
    connectButton.disabled = true;
    return;
  }

  // Add placeholder as first option (non-selectable)
  const placeholder = document.createElement("option");
  placeholder.value = "";
  placeholder.disabled = true;
  placeholder.selected = true;
  placeholder.textContent = "— Selecione o firmware —";
  fwsel.appendChild(placeholder);

  const versions = boardFirmwares[board] || [];
  versions.forEach((v) => {
    const opt = document.createElement("option");
    opt.value = v;
    opt.textContent = v;
    fwsel.appendChild(opt);
  });

  connectButton.disabled = true;
  updateVersionLabel();
}

function updateVersionLabel() {
  const fw = fwsel.value || "";
  document.getElementById("jadediyversion").innerHTML = fw ? "Firmware Version: " + fw : "Firmware Version";
  connectButton.disabled = !fw;
}

boardsel.addEventListener("change", updateFirmwareOptions);
fwsel.addEventListener("change", updateVersionLabel);

// Initialize on load
updateFirmwareOptions();

connectButton.onclick = async () => {
  const board = boardsel.value;
  const firmware = fwsel.value;

  connectButton.style.display = "none";
  lblboard.style.display = "none";
  lblfw.style.display = "none";
  boardsel.style.display = "none";
  fwsel.style.display = "none";

  if (device === null) {
    device = await navigator.serial.requestPort({});
    transport = new Transport(device);
  }

  btprogressBar.style.display = "block";
  otaprogressBar.style.display = "block";
  ptprogressBar.style.display = "block";
  jadeprogressBar.style.display = "block";

  btprogressBarLbl.style.display = "block";
  otaprogressBarLbl.style.display = "block";
  ptprogressBarLbl.style.display = "block";
  jadeprogressBarLbl.style.display = "block";

  var baudrate = 921600;

  try {
    esploader = new ESPLoader(transport, baudrate, null);
    chip = await esploader.main_fn();
  } catch (e) {
    console.error(e);
  }

  // S3 boards use different flash addresses
  var addressesAndFiles;
  if (board.includes("s3")) {
    addressesAndFiles = [
      { address: "0x0", fileName: "bootloader.bin", progressBar: btprogressBar },
      { address: "0x8000", fileName: "partition-table.bin", progressBar: ptprogressBar },
      { address: "0x1a000", fileName: "ota_data_initial.bin", progressBar: otaprogressBar },
      { address: "0x20000", fileName: "jade.bin", progressBar: jadeprogressBar },
    ];
  } else {
    addressesAndFiles = [
      { address: "0x1000", fileName: "bootloader.bin", progressBar: btprogressBar },
      { address: "0x9000", fileName: "partition-table.bin", progressBar: ptprogressBar },
      { address: "0xE000", fileName: "ota_data_initial.bin", progressBar: otaprogressBar },
      { address: "0x10000", fileName: "jade.bin", progressBar: jadeprogressBar },
    ];
  }

  let fileArray = [];

  for (const item of addressesAndFiles) {
    console.log(`Address: ${item.address}, File Name: ${item.fileName}`);
    // New path: assets/<board>/<version>/<file>
    const response = await fetch("assets/" + board + "/" + firmware + "/" + item.fileName);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    const fileBlob = await response.blob();
    const fileData = await new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onloadend = () => resolve(reader.result);
      reader.onerror = reject;
      reader.readAsBinaryString(fileBlob);
    });
    fileArray.push({
      data: fileData,
      address: item.address,
    });
  }
  try {
    await esploader.write_flash(
      fileArray,
      "keep",
      "keep",
      "keep",
      false,
      true,
      (fileIndex, written, total) => {
        addressesAndFiles[fileIndex].progressBar.value = (written / total) * 100;
      },
      null,
    );
  } catch (e) {
    console.error(e);
  }
  await new Promise((resolve) => setTimeout(resolve, 100));
  await transport.setDTR(false);
  await new Promise((resolve) => setTimeout(resolve, 100));
  await transport.setDTR(true);
  document.getElementById("success").innerHTML =
    "Successfully flashed CaTeIM Jade DIY " + firmware + " on " + boardNames[board];
  await incrementFlashCount();
};
