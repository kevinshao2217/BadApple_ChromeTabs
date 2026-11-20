# bad-apple-but-chrome-tabs

[English](README.md) | [繁體中文說明文件](README_zh.md)

透過實體 Google Chrome 瀏覽器分頁網格矩陣播放《Bad Apple!!》的視覺化實驗專案。

每個瀏覽器分頁透過動態 Favicon（網站圖標）作為獨立顯示像素，利用 `BroadcastChannel` 進行跨視窗微秒級同步，並透過 Win32 API 實現精確的視窗垂直物理疊加排列。

YouTube 展示影片：https://youtu.be/635om6J0NTY?si=IloZtKU8JsOKxmEh

---

## 系統架構概觀

```
                      +-----------------------------+
                      |   master.html (控制中樞)    |
                      |  - 視訊解碼與畫格降採樣    |
                      |  - 二值化閾值處理與點陣圖化|
                      +--------------+--------------+
                                     |
                BroadcastChannel (bam-ctl / bam-t-{r}-{c})
                                     |
          +---------------------------+---------------------------+
          |                           |                           |
          v                           v                           v
+------------------+        +------------------+        +------------------+
| 視窗 0 (第 0 列) |        | 視窗 1 (第 1 列) |        | 視窗 N (第 N 列) |
| [分頁 0][分頁 1].|        | [分頁 0][分頁 1].|        | [分頁 0][分頁 1].|
+------------------+        +------------------+        +------------------+
          |                           |                           |
          +---------------------------+---------------------------+
                                     |
                     arrange.ps1 (Win32 user32.dll)
              依垂直間距 (Pitch) 偏移並堆疊 Chrome 視窗
                    -> 僅露出頂部分頁標籤列 (Tab Bar)
```

### 關鍵核心技術機制

1. **Favicon 畫素渲染引擎 (`tile.html`)**：
   - 每個分頁訂閱獨立的座標通訊頻道（`bam-t-{r}-{c}`）。
   - 動態於 16x16 HTML5 Canvas 生成圖像，序列化為 PNG Data URL 並注入 `<link rel="icon">`。
   - **增量差異傳輸 (Delta Transmission)**：控制中樞僅在單元格黑白狀態發生反轉（Flip）時發送廣播，大幅降低 IPC 負載。
   - **畫格合併與丟棄 (Frame Coalescing)**：透過 `MessageChannel` 微任務佇列主動丟棄過期的排隊畫格，徹底避免分頁喚醒延遲與畫面撕裂脫節。

2. **Win32 視窗物理矩陣堆疊 (`arrange.ps1`)**：
   - 於 PowerShell 中直接以 P/Invoke 叫用原生 `user32.dll` API（`SetWindowPos`、`EnumWindows`、`GetWindowRect`）。
   - 將各個獨立的 Chrome 視窗依序按固定像素垂直間距（預設 45px）階梯式偏移堆疊，以視窗邊框物理遮蔽下層內容，形成由實體分頁標籤組成的無縫顯示器陣列。

3. **瀏覽器後台節流阻斷機制 (`spawn_matrix.bat` 與 `server.js`)**：
   - 啟動完全隔離的專用 Chrome 使用者設定檔（`--user-data-dir=chrome-profile`）。
   - 強制注入底層 Flag，關閉 Chromium 對非作用中視窗的計時器節流與遮擋剔除：
     - `--disable-renderer-backgrounding`
     - `--disable-background-timer-throttling`
     - `--disable-backgrounding-occluded-windows`
     - `--disable-features=CalculateNativeWinOcclusion,IntensiveWakeUpThrottling`
     - `--renderer-process-limit=12`

4. **零外部依賴本地伺服器 (`server.js`)**：
   - 僅依賴 Node.js 官方標準函式庫（`http`、`child_process`、`fs`、`path`）。
   - 支援 HTTP Range 串流協定以確保高碼率視訊平滑解碼，並提供跨行程視窗矩陣排列觸發端點。

---

## 系統需求

- **作業系統**：Windows 10 / Windows 11（Win32 API 與 PowerShell 視窗編排必需）
- **瀏覽器**：Google Chrome
- **執行環境**：Node.js（建議 v14 以上版本，無需安裝任何第三方 `npm` 套件）

---

## 快速開始指南

### 1. 檔案準備
將 `bad_apple.mp4` 放置於本專案根目錄下（亦可於啟動後透過控制介面直接選取任何本機視訊檔案）。

### 2. 啟動控制中樞
在命令提示字元或終端機中執行啟動批次檔：
```cmd
spawn_matrix.bat
```
亦可傳入自訂行列維度參數（例如 5 列視窗、每列 40 個分頁）：
```cmd
spawn_matrix.bat 5 40
```
此指令將自動於連接埠 `8760` 啟動 `server.js`，並在隔離的專用 Chrome 實體中開啟 `http://localhost:8760/master.html` 控制面板。

### 3. 生成與排列矩陣
1. 進入 `master.html` 控制儀表板，確認或調整矩陣參數：
   - **Rows (列數)**：垂直堆疊的 Chrome 視窗數量。
   - **Cols (行數)**：各視窗內部開啟的分頁標籤數量。
   - **Pitch (間距)**：視窗垂直堆疊位移像素（預設 45px，符合 Windows 縮放 100% 之標籤高度）。
2. 點擊 **生成視窗 (Spawn Windows)**，系統將批次建立各列視窗及其對應的分頁矩陣。
3. 若視窗位置遭到手動移動，點擊 **重新排列 (Rearrange)** 即可重新執行 Win32 自動定位。
4. 點選 **Play (播放)**，即可於實體 Chrome 分頁陣列上觀看 Bad Apple 矩陣動態渲染。

---

## 專案結構說明

```
.
├── arrange.ps1       # Win32 視窗物理排列與網格計算腳本 (PowerShell)
├── master.html       # 控制中樞 UI、視訊採樣器與 BroadcastChannel 廣播調度器
├── row.html          # 列標題佔位分頁
├── tile.html         # 單元畫素分頁（動態 Favicon 生成器與佇列管理）
├── server.js         # 零依賴靜態資源伺服器與視窗排列 IPC 後端
├── spawn_matrix.bat  # 注入 Chrome 效能 Flag 之全自動啟動腳本
├── .gitignore        # 排除執行期暫存設定檔、媒體與日誌
├── README.md         # 英文架構說明文件
└── README_zh.md      # 繁體中文技術架構與操作指南
```

---

## 授權條款

MIT License. 自由用於個人研究、教學與創意衍生作品。
