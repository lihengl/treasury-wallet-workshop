# Solidity 多重簽章資金管理錢包工作坊

使用 Remix IDE 建立、測試及部署一個採用「三人中至少兩人核准」（2-of-3）機制的 ETH 資金管理錢包。資金管理人員提出付款申請，兩位擁有者核准後，再由一位擁有者執行付款。

## 目錄

- [專案概述](#專案概述)
- [檔案與事前準備](#檔案與事前準備)
- [1. 在 Remix 中開啟專案](#1-在-remix-中開啟專案)
- [2. 編譯錢包合約](#2-編譯錢包合約)
- [3. 部署至 Remix VM](#3-部署至-remix-vm)
- [4. 存入 ETH](#4-存入-eth)
- [5. 手動操作付款流程](#5-手動操作付款流程)
- [6. 執行自動化測試](#6-執行自動化測試)
- [7. 部署至 Ethereum Sepolia 測試網路](#7-部署至-ethereum-sepolia-測試網路)
- [8. 將專案發布至 GitHub](#8-將專案發布至-github)
- [常見問題排解](#常見問題排解)
- [參考資料](#參考資料)

## 專案概述

錢包有三位固定的擁有者（owner），每筆付款都需要其中兩位核准。任何擁有者都可以提出付款申請。提案人也必須另外呼叫核准函式，才能記錄自己的核准。取得兩位擁有者的核准後，任何擁有者都可以執行該筆付款。

| 函式 | 用途 |
| --- | --- |
| `proposePayment(recipient, amount)` | 記錄收款地址與金額，付款編號從 `0` 開始。 |
| `approvePayment(paymentId)` | 記錄呼叫者對該筆付款的核准，每人限核准一次。 |
| `executePayment(paymentId)` | 取得兩位擁有者的核准後，轉出 ETH。 |
| `payments(paymentId)` | 讀取收款地址、金額、核准次數與執行狀態。 |
| `hasApproved(paymentId, owner)` | 查詢某位擁有者是否已核准該筆付款。 |
| `isOwner(address)` | 查詢某個地址是否為擁有者。 |
| `paymentCount()` | 讀取已建立的付款申請總數。 |
| `walletBalance()` | 讀取合約的 ETH 餘額，單位為 wei。 |
| `REQUIRED_APPROVALS()` | 讀取核准門檻，數值為 `2`。 |

任何人都可以存入 ETH。每筆付款成功後只能執行一次。若轉帳失敗，執行狀態與餘額變動會一併還原，已取得的核准仍會保留，供之後再次嘗試。

工作坊使用模擬 ETH 與 Sepolia ETH 進行練習。這份實作以教學為目的，透過固定的擁有者與核准門檻控制專案規模。擁有者管理、撤回核准等功能可留待後續擴充。

## 檔案與事前準備

| 路徑 | 內容 |
| --- | --- |
| [README.md](README.md) | 完整工作坊操作指南。 |
| [contracts/TreasuryWallet.sol](contracts/TreasuryWallet.sol) | 錢包實作，所有邏輯集中於一個 Solidity 檔案，無須外部相依套件。 |
| [tests/TreasuryWallet_test.sol](tests/TreasuryWallet_test.sol) | 七項自動化測試。 |
| [tests/WalletTestActor.sol](tests/WalletTestActor.sol) | 測試輔助合約，提供不同的呼叫者與 ETH 收款對象。 |

瀏覽器練習需要桌面版瀏覽器與網路連線。Sepolia 章節另外需要 MetaMask 瀏覽器擴充功能，以及透過水龍頭（faucet）取得的 Sepolia ETH。Remix VM 練習可完全在 Remix 中完成。

兩個測試檔案都會匯入 `../contracts/TreasuryWallet.sol`。將檔案複製到 Remix 時，請維持上表的目錄結構。如果已有其他專案結構，請配合實際路徑調整 `import`。

## 1. 在 Remix 中開啟專案

1. 在電腦上解壓縮下載的 ZIP 檔案。
2. 使用桌面版瀏覽器開啟 [Remix IDE](https://remix.ethereum.org/)。
3. 開啟左側欄的 **File Explorer**。
4. 建立 `contracts` 與 `tests` 資料夾。可使用 **Create** 選單，或在檔案區按滑鼠右鍵，建立資料夾與檔案。
5. 建立 `contracts/TreasuryWallet.sol`，並貼上提供的錢包原始碼全文。
6. 建立 `tests/TreasuryWallet_test.sol` 與 `tests/WalletTestActor.sol`，分別貼上對應檔案的完整內容。
7. 對照上表，確認檔名與路徑正確。

錢包檔案的前兩行應如下所示。

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
```

## 2. 編譯錢包合約

1. 選取 `contracts/TreasuryWallet.sol`，讓它成為編輯器目前開啟的分頁。
2. 開啟左側欄的 **Solidity Compiler**。
3. 將編譯器版本設為 **0.8.20**。
4. 開啟 **Advanced Configurations**，將 EVM 版本設為 **Shanghai**，啟用最佳化，並將 runs 設為 **200**。整個工作坊及測試皆使用這組設定。
5. 點選 **Compile TreasuryWallet.sol**。
6. 確認編譯成功，且合約下拉選單中出現 `TreasuryWallet`。可透過 **Compilation Details** 查看 ABI 與位元組碼（bytecode）。

編譯器會將原始碼轉換為可執行的位元組碼，並產生供工具呼叫合約的 ABI。明確指定編譯器與 EVM 版本，有助於讓每位學員使用一致的設定。啟用最佳化也能將自動化測試合約的大小控制在可部署的範圍內。

## 3. 部署至 Remix VM

### 分配角色

1. 開啟 **Deploy & Run Transactions**。
2. 若選單中有 **Remix VM (Shanghai)**，請選取它，也可選擇支援 Shanghai 位元組碼的一般 Remix VM。
3. 從 **Account** 選單複製四個不同 VM 帳戶的完整地址，並依照下表分配角色。角色名稱用於識別練習中的帳戶，呼叫函式時請填入各帳戶的實際地址。

| 角色 | 建議帳戶 | 職責 |
| --- | --- | --- |
| Treasury（資金管理） | 第一個帳戶 | 部署、提案與核准。 |
| Finance（財務） | 第二個帳戶 | 提供第二份核准。 |
| Risk（風控） | 第三個帳戶 | 執行已核准的付款。 |
| Vendor（供應商） | 第四個帳戶 | 收取款項，並用來測試擁有者權限限制。 |

### 部署合約

1. 將 **Account** 切換為 Treasury。
2. 選取 `TreasuryWallet` 作為要部署的合約。
3. 將 **Value** 設為 `0`。
4. 如有需要，展開 **Deploy** 旁的建構子（constructor）輸入欄位。在 `owner1` 填入 Treasury 的地址、`owner2` 填入 Finance 的地址、`owner3` 填入 Risk 的地址。
5. 點選 **Deploy**，並展開 **Deployed Contracts** 下方新增的合約實例。
6. 以三位擁有者的地址分別呼叫 `isOwner`，結果都應為 `true`。若輸入 Vendor 的地址，結果應為 `false`。
7. 呼叫 `walletBalance` 與 `paymentCount`，結果都應為 `0`。

三位擁有者的地址必須互不相同，且都不能是零地址。擁有者身分由建構子參數決定。明確將 Treasury 填入其中一個參數，才能讓部署者 Treasury 同時具有擁有者權限。

## 4. 存入 ETH

1. 將 **Value** 設為 `3`，單位選擇 **Ether**。
2. 在已部署的錢包下方展開 **Low level interaction**。
3. 將 **Calldata** 留空，點選 **Transact**。這會呼叫 `receive()`，將 ETH 存入錢包。
4. 在接下來呼叫任何函式之前，先將 **Value** 重設為 `0`。
5. 呼叫 `walletBalance`，預期結果為 `3000000000000000000` wei，相當於 **3 ETH**。

付款金額一律以 wei 輸入。**Value** 欄位代表本次交易附帶的 ETH 金額。`amount` 參數則記錄錢包之後應從自身餘額支付多少款項。

| ETH | Wei |
| --- | --- |
| 3 | `3000000000000000000` |
| 1 | `1000000000000000000` |
| 0.001 | `1000000000000000` |
| 0.0001 | `100000000000000` |

## 5. 手動操作付款流程

使用前面步驟部署的錢包，並將 **Value** 維持為 `0`。透過 **Account** 下拉選單切換呼叫者，展開函式後即可分別輸入各項參數。

### 提出付款申請並核准

1. 選擇 **Treasury**。呼叫 `proposePayment`，在 `recipient` 填入 Vendor 的地址，並在 `amount` 填入 `1000000000000000000`。
2. 呼叫 `paymentCount`，預期結果為 `1`。以編號 `0` 呼叫 `payments`，預期會讀到 Vendor 的地址、金額 `1000000000000000000`、`approvalCount = 0` 與 `executed = false`。
3. 選擇 **Vendor** 並記錄目前的帳戶餘額。嘗試呼叫 `approvePayment(0)`，預期會出現 `Only an owner`。
4. 選擇 **Treasury** 並呼叫 `approvePayment(0)`。再次讀取 `payments(0)`，核准次數應為 `1`。
5. 以 Treasury 再次嘗試呼叫 `approvePayment(0)`，預期會出現 `Owner already approved`。
6. 以 Treasury 嘗試呼叫 `executePayment(0)`，預期會出現 `Need two approvals`。
7. 選擇 **Finance** 並呼叫 `approvePayment(0)`。再次讀取 `payments(0)`，預期已有兩份核准，且 `executed = false`。
8. 呼叫 `walletBalance`，餘額應仍為 **3 ETH**。如果 Vendor 的核准嘗試在送出前便已取消，其帳戶餘額也應與先前相同。

### 執行付款並檢查結果

1. 選擇 **Risk** 並呼叫 `executePayment(0)`。
2. 再次呼叫 `payments(0)`，預期會看到 `executed = true`。
3. 呼叫 `walletBalance`，預期結果為 `2000000000000000000`，相當於 **2 ETH**。
4. 選擇 **Vendor** 並檢查餘額，應已收到 **1 ETH**。如果 Vendor 先前失敗的交易實際上已被打包進區塊，該筆交易的 gas 費用也會影響餘額。
5. 選擇 **Risk** 並再次嘗試呼叫 `executePayment(0)`，預期會出現 `Payment already executed`。
6. 在 Remix 終端機展開成功交易的紀錄，查看其中的事件日誌，包括 `PaymentProposed`、`PaymentApproved` 與 `PaymentExecuted`。

兩份核准代表付款已獲授權，接著透過獨立的執行交易實際轉出款項。

### 處理預期中的失敗

Remix 可能在送出交易前的 gas 估算階段就回報 revert。如果訊息符合預期的失敗原因，取消該次操作並繼續練習即可。若交易已被打包進區塊，即使執行時發生 revert，仍會消耗 gas。

## 6. 執行自動化測試

### 設定並執行

1. 確認兩個測試檔案都位於 `tests/`，錢包合約位於 `contracts/`。
2. 開啟 **Solidity Compiler**，設定為 **0.8.20**、**Shanghai**、啟用最佳化，並將 runs 設為 **200**。
3. 開啟 **Plugin Manager**，搜尋 **Solidity Unit Testing** 並啟用。
4. 開啟測試外掛，選擇既有的 `/tests` 目錄作為測試目錄。
5. 選取 `TreasuryWallet_test.sol`，點選 **Run**。
6. 預期結果為 **7 passed, 0 failed**，即七項通過、零項失敗。若有失敗，可點選該測試查看斷言的詳細資訊。

測試執行器會提供測試套件匯入的斷言函式庫 `remix_tests.sol`。`beforeEach()` 會在每項測試前建立新的錢包與不同的呼叫者合約。NatSpec 的 `#value` 註記會提供模擬 ETH 給可收款的測試函式。測試會在專用環境中執行，並自行建立錢包實例。

### 測試涵蓋的行為

| 測試 | 預期行為 |
| --- | --- |
| `rejectsInvalidOwners` | 拒絕重複的擁有者地址與零地址。 |
| `rejectsNonOwners` | 未具擁有者身分的帳戶無法提案、核准或執行付款。 |
| `rejectsUnknownPayment` | 核准及執行函式會拒絕不存在的付款編號。 |
| `requiresTwoDistinctApprovals` | 存款與提案欄位正確，提案初始核准次數為零，重複核准會失敗，且僅有一份核准時無法執行。 |
| `paysOnceAfterTwoApprovals` | 核准後、執行前的餘額維持原值，執行時確實付款一次，且重複執行會失敗。 |
| `canRetryAfterFunding` | 錢包原本沒有餘額時，已核准的付款可在存入足夠 ETH 後成功執行。 |
| `preservesStateWhenRecipientRejectsETH` | 收款方拒收 ETH 時，餘額、核准紀錄及尚未執行的狀態都會保留。 |

`WalletTestActor` 會轉送函式呼叫，讓每個合約實例提供不同的 `msg.sender`。輔助合約的檔名以 `.sol` 結尾，測試套件則以 `_test.sol` 結尾，供測試執行器辨識。

## 7. 部署至 Ethereum Sepolia 測試網路

### 準備帳戶

1. 從官方提供的管道安裝 MetaMask 瀏覽器擴充功能，並開啟它。
2. 開啟 **Networks**，啟用 **Show test networks**，選擇 **Ethereum Sepolia**。其 chain ID 為 `11155111`。
3. 建立或選擇三個自己能操作的錢包帳戶，將地址分別記錄為 Treasury、Finance 與 Risk，另以第四個地址作為 Vendor。此練習請使用能透過 MetaMask 簽署交易的帳戶。
4. 從 [ethereum.org 的 Sepolia 水龍頭清單](https://ethereum.org/developers/docs/networks/#sepolia)選擇水龍頭，替 Treasury 取得 Sepolia ETH。
5. 替 Finance 準備核准交易所需的 gas 費用。如果要由 Risk 執行付款，也需替它準備資金。每個送出交易的帳戶，都需要以自身的 Sepolia ETH 支付 gas。Treasury 的餘額應足以支付部署、存款及後續交易。

### 連線並部署

1. 在 Remix 選取 `contracts/TreasuryWallet.sol`，使用第 2 節的設定進行編譯。
2. 開啟 **Deploy & Run Transactions**，選擇 **Browser Extension**。較舊版本的 Remix 可能將此選項標示為 **Injected Provider - MetaMask**。
3. 在 MetaMask 允許連線。確認目前連線的網路為 Sepolia，且選取的帳戶為 Treasury。之後切換帳戶時，請確認新帳戶已連線至 Remix，且顯示為目前的呼叫者。
4. 選擇 `TreasuryWallet`，並將 **Value** 設為 `0`。
5. 在三個建構子欄位分別填入 Treasury、Finance 與 Risk，使用前面記錄的 Sepolia 錢包地址。
6. 點選 **Deploy**，在 MetaMask 確認網路與費用後核准交易。
7. 等待交易確認，再從 **Deployed Contracts** 複製合約地址。
8. 在 [Sepolia Etherscan](https://sepolia.etherscan.io/) 搜尋該地址，確認建立合約的交易成功。
9. 在 Remix 以三位擁有者的地址分別呼叫 `isOwner`，預期結果皆為 `true`。呼叫 `walletBalance`，預期結果為 `0`。

### 存款並操作已部署的錢包

1. 使用 MetaMask 將 **0.001 Sepolia ETH** 傳送至已部署的合約地址，並等待交易確認。
2. 在 Remix 呼叫 `walletBalance`，預期結果為 `1000000000000000` wei。
3. 選擇 Treasury，呼叫 `proposePayment`，填入 Vendor 的地址與 `100000000000000` wei，相當於 **0.0001 ETH**。這個新部署錢包的第一筆付款申請編號為 `0`。
4. 以 Treasury 呼叫 `approvePayment(0)`，在 MetaMask 核准交易，並等待交易確認。
5. 切換為 Finance，確認 Remix 顯示的呼叫者為 Finance，再送出 `approvePayment(0)`，並等待交易確認。
6. 切回 Treasury，送出 `executePayment(0)`，並等待交易確認。
7. 檢查 `payments(0)`，應看到 `executed = true`。檢查 `walletBalance`，預期為 `900000000000000` wei，相當於 **0.0009 ETH**。

呼叫者以個人帳戶的餘額支付 gas 費用，資金管理錢包則以合約餘額支付提案中的付款金額。

### 之後重新連線至同一個合約

1. 在 Remix 再次透過 MetaMask 連線至 Sepolia。
2. 使用部署時相同的設定編譯錢包合約。
3. 在 **Deployed Contracts** 下選擇 **Add Contract**，輸入先前保存的合約地址並加入。較舊版本的 Remix 可能將此功能標示為 **At Address**。
4. 使用載入的合約實例讀取狀態及送出後續交易。

## 8. 將專案發布至 GitHub

1. 為工作坊建立 GitHub 儲存庫。
2. 將解壓縮後的 `treasury-wallet-workshop` 資料夾內所有檔案上傳至儲存庫根目錄，保留 `contracts/` 與 `tests/` 的結構。
3. 確認 `README.md` 位於儲存庫根目錄，讓 GitHub 在專案首頁顯示這份指南。
4. 開啟上方檔案表格中的原始碼相對連結，確認兩個目錄與其中檔案皆可正常存取。

## 常見問題排解

| 狀況 | 檢查方式 |
| --- | --- |
| 編譯按鈕顯示其他檔名 | 在編輯器選取 `contracts/TreasuryWallet.sol`。 |
| 測試的匯入路徑錯誤 | 兩個測試相關檔案都應匯入 `../contracts/TreasuryWallet.sol`，測試套件另外匯入 `./WalletTestActor.sol`。 |
| 測試合約過大或部署失敗 | 啟用編譯器最佳化，將 runs 設為 200，再重新執行測試。 |
| 無法解析 `remix_tests.sol` | 透過 **Solidity Unit Testing** 執行測試，由外掛提供斷言函式庫。 |
| 可收款的測試沒有 ETH | 保留其 `/// #value: ...` 註記，並透過測試外掛執行。 |
| 部署失敗 | 將 Value 設為零，並提供三個互不相同且非零的擁有者地址。 |
| `Only an owner` | 檢查目前選取的呼叫者，並查詢 `isOwner(callerAddress)`。 |
| `Unknown payment` | 付款編號從零開始，請使用已建立且小於 `paymentCount()` 的編號。 |
| `Owner already approved` | 改由另一位擁有者提供第二份核准。 |
| `Need two approvals` | 讀取 `payments(id)`，確認已取得兩位不同擁有者的核准。 |
| `Insufficient wallet balance` | 將足夠的 ETH 存入合約。 |
| `ETH transfer failed` | 收款方可能拒收 ETH，請檢查收款方的行為與待執行的付款。 |
| 變更狀態的函式呼叫意外拒收 ETH | 呼叫前先將 Remix 的 Value 欄位重設為零。 |
| MetaMask 顯示餘額不足 | 替目前選取的帳戶準備足夠資金，以支付 gas 及本次交易附帶的 ETH。 |
| Sepolia 交易持續顯示待確認 | 再次操作前，先在 MetaMask 或 Sepolia Etherscan 查看該筆交易的狀態。 |

## 參考資料

Remix 的介面標籤可能因版本而異。以下官方文件涵蓋本指南使用的功能。

- [Remix 檔案總管](https://remix-ide.readthedocs.io/en/latest/file_explorer.html)
- [Remix Solidity 編譯器](https://remix-ide.readthedocs.io/en/latest/compile.html)
- [Remix 部署與執行](https://remix-ide.readthedocs.io/en/latest/run.html)
- [Remix 合約互動操作](https://remix-ide.readthedocs.io/en/latest/udapp.html)
- [Remix Solidity 單元測試](https://remix-ide.readthedocs.io/en/latest/unittesting.html)
- [MetaMask 測試網路設定](https://support.metamask.com/configure/networks/how-to-view-testnets-in-metamask/)
- [Ethereum 網路與 Sepolia 水龍頭](https://ethereum.org/developers/docs/networks/#sepolia)
