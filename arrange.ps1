# 把矩陣用的 Chrome 視窗疊成一排排分頁列（後面的視窗蓋住前面視窗的內容，只露出分頁列）
# 找視窗的方式：
#   有 -Profile 時：屬於「用這個設定檔啟動的 Chrome」的所有視窗（控制頁面除外）——不管作用中的是哪個分頁都找得到
#   否則：標題是 "ROW nn" 的視窗
param(
  [int]$Pitch = 45,     # 每排的垂直距離（實體像素）
  [int]$Top = 0,
  [int]$Left = -1,      # -1 = 螢幕左緣
  [int]$Width = -1,     # -1 = 螢幕寬
  [int]$Height = -1,    # -1 = 盡量矮（= 每排間距，Chrome 會自動限制最小高度）
  [int]$Only = -1,      # 只移動這一排（生成時每開一排就立刻放好）
  [string]$Profile = "",
  [switch]$Close        # 關閉所有像素視窗（連同其中的分頁）
)
[Console]::OutputEncoding = [Text.Encoding]::UTF8
Add-Type @"
using System; using System.Text; using System.Runtime.InteropServices; using System.Collections.Generic;
public class W {
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr p);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint cmd);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  public class Win { public IntPtr H; public string Title; public uint Pid; public int Z; }
  public static List<Win> List() {
    var r = new List<Win>(); int z = 0;
    EnumWindows((h, p) => {
      if (IsWindowVisible(h) && GetWindow(h, 4) == IntPtr.Zero) {
        var c = new StringBuilder(64); GetClassName(h, c, 64);
        if (c.ToString() == "Chrome_WidgetWin_1") {
          var s = new StringBuilder(512); GetWindowText(h, s, 512); uint pid; GetWindowThreadProcessId(h, out pid);
          r.Add(new Win { H = h, Title = s.ToString(), Pid = pid, Z = z++ });
        }
      }
      return true; }, IntPtr.Zero);
    return r;
  }
}
"@
[W]::SetProcessDPIAware() | Out-Null
$sw = [W]::GetSystemMetrics(0); $sh = [W]::GetSystemMetrics(1)
if ($Left -lt 0) { $Left = 0 }
if ($Width -lt 0) { $Width = $sw }

$all = [W]::List()
if ($Profile) {
  $needle = $Profile.TrimEnd('\').ToLower()
  $pids = @(Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" |
    Where-Object { $_.CommandLine -and $_.CommandLine.ToLower().Contains($needle) } | ForEach-Object { [uint32]$_.ProcessId })
  $wins = @($all | Where-Object { $pids -contains $_.Pid -and -not $_.Title.StartsWith("Tab Matrix") })
} else {
  $wins = @($all | Where-Object { $_.Title.StartsWith("ROW ") })
}
if ($wins.Count -eq 0) { Write-Host "找不到像素視窗。請先在控制頁面按「生成視窗」。"; exit 1 }

if ($Close) {
  foreach ($w in $wins) { [W]::PostMessage($w.H, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null }
  Write-Host ("已關閉 {0} 個視窗。" -f $wins.Count)
  exit 0
}

# 排序：標題是 ROW nn 的照排號；其他（使用者點到別的分頁）排在後面，依視窗疊放順序
# 位置依排號：第 r 排放在 y = Top + r × Pitch；標題不是 ROW 的視窗排在最後一排之後
$rowOf = { param($w) if ($w.Title -match '^ROW (\d+)') { [int]$matches[1] } else { -1 } }
$sorted = $wins | Sort-Object @{ Expression = { $r = & $rowOf $_; if ($r -lt 0) { 100000 } else { $r } } }, @{ Expression = { -$_.Z } }
$maxRow = ($wins | ForEach-Object { & $rowOf $_ } | Measure-Object -Maximum).Maximum
$next = [int]$maxRow + 1
$h = if ($Height -gt 0) { $Height } else { $Pitch }
$n = 0; $unknown = 0
foreach ($w in $sorted) {
  $r = & $rowOf $w
  if ($r -lt 0) { $r = $next; $next++; $unknown++ }
  if ($Only -ge 0 -and $r -ne $Only) { continue }
  $y = $Top + $r * $Pitch
  [W]::ShowWindow($w.H, 9) | Out-Null
  [W]::SetWindowPos($w.H, [IntPtr]::Zero, $Left, $y, $Width, $h, 0x0040) | Out-Null
  $n++
}
if ($Only -ge 0) { Write-Host "row $Only placed"; exit 0 }
$msg = "完成：$n 個視窗，第 r 排在 y = $Top + r × $Pitch。"
if ($unknown) { $msg += " 其中 $unknown 個視窗作用中的不是 ROW 分頁，排序可能不對：點一下那些視窗最左邊的分頁再按「重新排列」。" }
Write-Host $msg
