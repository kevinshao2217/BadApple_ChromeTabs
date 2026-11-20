# bad-apple-but-chrome-tabs

Bad Apple!! played across hundreds of live Google Chrome browser tabs arranged in a physical visual matrix.

Each tab acts as an individual display pixel using dynamic favicon rendering, synchronized in real time via `BroadcastChannel` and arranged using Win32 API window overlapping.

Here is a Demo on YouTube https://youtu.be/635om6J0NTY?si=IloZtKU8JsOKxmEh
---

### Key Technical Mechanisms

1. **Favicon Display Engine (`tile.html`)**:
   - Each tab subscribes to a dedicated coordinate channel (`bam-t-{r}-{c}`).
   - Dynamically generates 16x16 canvas image data, serialized as PNG data URLs and set to `<link rel="icon">`.
   - **Delta Transmission**: The master controller only transmits messages when a cell's pixel state actually flips.
   - **Frame Coalescing**: Uses `MessageChannel` microtask queuing to drop obsolete queued frames, preventing tab wake-up stalls and desync.

2. **Window Overlapping Matrix (`arrange.ps1`)**:
   - Uses native `user32.dll` Win32 APIs (`SetWindowPos`, `EnumWindows`, `GetWindowRect`) via PowerShell.
   - Cascades and offsets Chrome window rows by a configurable pixel pitch (default 45px), masking window content and presenting an aligned grid of physical tab headers.

3. **Background Throttling Bypass (`spawn_matrix.bat` & `server.js`)**:
   - Launches an isolated Chrome instance (`--user-data-dir=chrome-profile`).
   - Disables timer throttling and occlusion culling flags:
     - `--disable-renderer-backgrounding`
     - `--disable-background-timer-throttling`
     - `--disable-backgrounding-occluded-windows`
     - `--disable-features=CalculateNativeWinOcclusion,IntensiveWakeUpThrottling`
     - `--renderer-process-limit=12`

4. **Zero-Dependency Local Server (`server.js`)**:
   - Built solely with Node.js standard libraries (`http`, `child_process`, `fs`, `path`).
   - Provides HTTP Range request support for smooth video streaming and IPC endpoints for window orchestration.

---

## System Requirements

- **Operating System**: Windows 10 / Windows 11 (required for Win32 PowerShell window positioning)
- **Browser**: Google Chrome
- **Runtime**: Node.js (v14+ recommended, zero external `npm` packages required)

---

## Quick Start

### 1. Preparation
Place a copy of `bad_apple.mp4` into this project directory (or select any video file directly through the UI).

### 2. Launch Controller
Run the launcher batch file:
```cmd
spawn_matrix.bat
```
Optionally pass initial dimensions (e.g. 5 rows, 40 tabs):
```cmd
spawn_matrix.bat 5 40
```
This starts `server.js` on port `8760` and opens `http://localhost:8760/master.html` in an isolated Chrome instance.

### 3. Generate & Align Matrix
1. In the `master.html` dashboard, adjust target matrix dimensions:
   - **Rows**: Number of Chrome windows stacked vertically.
   - **Cols**: Number of tabs opened per window.
   - **Pitch**: Vertical offset between rows in physical pixels.
2. Click **生成視窗 (Spawn Windows)** to launch the matrix tabs.
3. Click **重新排列 (Rearrange)** to re-align windows if moved.
4. Load your video, hit **Play**, and watch the matrix render.

---

## Project Structure

```
.
├── arrange.ps1       # Win32 window positioning script (PowerShell)
├── master.html       # Controller UI, video sampler, and broadcast dispatcher
├── row.html          # Row title dummy tab
├── tile.html         # Individual pixel tab with dynamic favicon renderer
├── server.js         # Zero-dependency HTTP static & IPC backend
├── spawn_matrix.bat  # Automated launcher with Chrome performance flags
├── .gitignore        # Ignores runtime profile, media, and logs
└── README.md
```

---

## License

MIT License. Free for personal, research, and creative use.
