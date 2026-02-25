# CaTeIM Jade DIY Flasher

A web-based flasher utility for **Jade DIY** hardware wallets built on ESP32 boards.

## Supported Boards

| Board               | Chip     |
| ------------------- | -------- |
| LILYGO T-Display    | ESP32    |
| LILYGO T-Display S3 | ESP32-S3 |
| Waveshare ESP32-S3  | ESP32-S3 |

## How It Works

1. Open the [CaTeIM Jade DIY Flasher](https://cateim.github.io/jadediyflasher/) in Chrome or Edge
2. Select your **board**
3. Select the **firmware version**
4. Click **Flash Firmware** and select the serial port
5. Wait for the flash to complete

> **Note:** This tool uses the [Web Serial API](https://developer.mozilla.org/en-US/docs/Web/API/Serial) and only works in Chromium-based browsers (Chrome, Edge 89+).

## ⚠ Warning

This tool does **not** enable secure boot or flash encryption on DIY devices.

## Development

```bash
npm install
npm run build
python3 -m http.server 8008
```

Then open http://localhost:8008 in Chrome or Edge. The `npm run build` step builds the `bundle.js` used in the example `index.html`.

## License

The code in this repository is Copyright (c) 2021 Espressif Systems (Shanghai) Co. Ltd. It is licensed under Apache 2.0 license, as described in [LICENSE](LICENSE) file.
