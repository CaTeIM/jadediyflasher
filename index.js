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

// Abacus Counter API (free, no registration)
const ABACUS_URL = "https://abacus.jasoncameron.dev";
const COUNTER_NS = "cateim-jadediy";
const COUNTER_KEY = "flash-count";

async function loadFlashCount() {
  try {
    const res = await fetch(`${ABACUS_URL}/get/${COUNTER_NS}/${COUNTER_KEY}`);
    if (res.ok) {
      const data = await res.json();
      flashCountEl.textContent = data.value.toLocaleString("pt-BR");
    }
  } catch (_) {
    flashCountEl.textContent = "—";
  }
}

async function incrementFlashCount() {
  try {
    const res = await fetch(`${ABACUS_URL}/hit/${COUNTER_NS}/${COUNTER_KEY}`);
    if (res.ok) {
      const data = await res.json();
      flashCountEl.textContent = data.value.toLocaleString("pt-BR");
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
  tdisplay: ["1.0.40-100", "1.0.39", "1.0.38-98", "1.0.38"],
  tdisplays3: ["1.0.40-100", "1.0.39", "1.0.38-98", "1.0.38"],
  waveshares3: ["1.0.39", "1.0.38-98"],
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
  connectButton.disabled = !fw;
}

boardsel.addEventListener("change", updateFirmwareOptions);
fwsel.addEventListener("change", updateVersionLabel);

// Initialize on load
updateFirmwareOptions();

connectButton.onclick = async () => {
  const board = boardsel.value;
  const firmware = fwsel.value;

  const successEl = document.getElementById("success");
  const bootHint = document.querySelector(".boot-hint");

  // Elements toggled during the flash flow
  const flashUiEls = [connectButton, lblboard, lblfw, boardsel, fwsel, bootHint];
  const progressBars = [btprogressBar, ptprogressBar, otaprogressBar, jadeprogressBar];
  const progressLbls = [btprogressBarLbl, ptprogressBarLbl, otaprogressBarLbl, jadeprogressBarLbl];
  const restore = (els) => els.forEach((el) => el && (el.style.display = ""));
  const hide = (els) => els.forEach((el) => el && (el.style.display = "none"));
  const showBlock = (els) => els.forEach((el) => el && (el.style.display = "block"));

  // Drop the current connection so a retry starts from a clean state
  async function resetConnection() {
    try {
      if (transport) await transport.disconnect();
    } catch (_) {}
    device = null;
    transport = null;
    chip = null;
  }

  // Abort the flow: show a red error, re-enable the UI, allow a retry
  function fail(message, error) {
    if (error) console.error(error);
    hide(progressBars);
    hide(progressLbls);
    progressBars.forEach((bar) => (bar.value = 0));
    restore(flashUiEls);
    successEl.style.color = "#e85353"; // red
    successEl.innerHTML = message;
  }

  // Enter the flashing state
  hide(flashUiEls);
  successEl.style.color = "#e8c84a"; // yellow while flashing
  successEl.innerHTML = "Flashing Firmware " + firmware + " on " + boardNames[board] + "...";

  // 1. Request / open the serial port
  try {
    if (device === null) {
      device = await navigator.serial.requestPort({});
      transport = new Transport(device);
    }
  } catch (e) {
    fail("Flash cancelado: nenhuma porta serial foi selecionada.", e);
    return;
  }

  showBlock(progressBars);
  showBlock(progressLbls);

  var baudrate = 921600;

  // 2. Connect to the chip (sync / enter bootloader)
  try {
    esploader = new ESPLoader(transport, baudrate, null);
    chip = await esploader.main_fn();
  } catch (e) {
    await resetConnection();
    fail(
      "Falha ao conectar com a placa. Coloque-a em modo bootloader (segure BOOT ao conectar o USB) e tente novamente.",
      e,
    );
    return;
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

  // 3. Download the firmware binaries
  let fileArray = [];
  try {
    for (const item of addressesAndFiles) {
      console.log(`Address: ${item.address}, File Name: ${item.fileName}`);
      // Path: assets/<board>/<version>/<file>
      const response = await fetch("assets/" + board + "/" + firmware + "/" + item.fileName);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status} ao baixar ${item.fileName}`);
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
  } catch (e) {
    await resetConnection();
    fail("Falha ao baixar os arquivos de firmware. Verifique sua conexao e tente novamente.", e);
    return;
  }

  // 4. Write the firmware to flash
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
    await resetConnection();
    fail(
      "Falha ao gravar o firmware. A placa pode ter sido gravada parcialmente - repita o processo em modo bootloader.",
      e,
    );
    return;
  }

  // 5. Success: reset the board and report
  await new Promise((resolve) => setTimeout(resolve, 100));
  try {
    await transport.setDTR(false);
    await new Promise((resolve) => setTimeout(resolve, 100));
    await transport.setDTR(true);
  } catch (_) {}

  successEl.style.color = "#39d353"; // green
  successEl.innerHTML =
    "Successfully flashed CaTeIM Jade DIY " + firmware + " on " + boardNames[board];

  // Google Analytics: track flash event (only on a real success)
  if (typeof gtag === "function") {
    gtag("event", "flash_success", {
      board: board,
      board_name: boardNames[board],
      firmware_version: firmware,
      chip: chip || "unknown",
    });
  }

  // Increment visible counter (only on a real success)
  await incrementFlashCount();

  // Reload after 3 seconds to return to the install screen
  setTimeout(() => {
    window.location.reload();
  }, 3000);
};

// ---- Support / donation panel: copy-to-clipboard ----
async function copyAddress(addr) {
  if (navigator.clipboard && navigator.clipboard.writeText) {
    await navigator.clipboard.writeText(addr);
    return true;
  }
  // Fallback for browsers without the async Clipboard API
  const ta = document.createElement("textarea");
  ta.value = addr;
  ta.style.position = "fixed";
  ta.style.opacity = "0";
  document.body.appendChild(ta);
  ta.focus();
  ta.select();
  let ok = false;
  try {
    ok = document.execCommand("copy");
  } catch (_) {
    ok = false;
  }
  document.body.removeChild(ta);
  return ok;
}

document.querySelectorAll(".copy-btn").forEach((btn) => {
  btn.addEventListener("click", async () => {
    const addr = btn.dataset.addr;
    const label = btn.dataset.label || "";
    const icon = btn.querySelector(".copy-icon");
    let ok = false;
    try {
      ok = await copyAddress(addr);
    } catch (_) {
      ok = false;
    }

    if (icon) {
      const original = icon.dataset.original || icon.textContent;
      icon.dataset.original = original;
      icon.textContent = ok ? "✓ copiado!" : "erro ao copiar";
      btn.classList.toggle("copied", ok);
      setTimeout(() => {
        icon.textContent = original;
        btn.classList.remove("copied");
      }, 1500);
    }

    if (ok && typeof gtag === "function") {
      gtag("event", "donate_copy", { method: label });
    }
  });
});

const storeCta = document.querySelector(".store-cta");
if (storeCta) {
  storeCta.addEventListener("click", () => {
    if (typeof gtag === "function") gtag("event", "store_click");
  });
}
