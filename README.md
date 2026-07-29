# My Journey - World of Warcraft Addon

[![WoW Version](https://img.shields.io/badge/WoW-Retail-blue)](https://worldofwarcraft.com)
[![Language](https://img.shields.io/badge/Language-Lua-language)](https://www.lua.org)
[![Framework](https://img.shields.io/badge/Framework-Pure%20API%20%28No%20Libs%29-orange)]()

**My Journey** is a lightweight and minimalist addon for World of Warcraft designed to help players track their personal goals, long-term objectives, profession materials, mounts, and achievements directly within the game.

Developed entirely on the **pure Blizzard API (native Lua)**, the addon was designed to be extremely lightweight, stable, and free of dependencies on third-party frameworks (such as Ace3).

<img width="389" height="488" alt="myjourney_frame" src="https://github.com/user-attachments/assets/4bd486da-7729-4fbc-a851-0937052d3fd9" />

---

## ✨ Features

* **Centralized Tracking:** A clean and intuitive window to manage your notes and goals in real time.
* **Native Link Magic (Shift+Click):** Full support for linking items directly from your bag or collections using the original WoW system. For other elements such as achievements, quests, skills... it is necessary to link to the game chat and use the command (Shift+Click).
* **Modern Texture Support:** Updated interface icons using numeric `FileDataID` for full compatibility with the latest versions of the game.
* **Character Filter:** Visual option to switch between displaying all saved goals on the account or only the goals of the current character (`Realm-Name`).
* **Integrated Editor:** Click "Edit" to return the goal to the input field, allowing quick corrections without losing data.
* **Dynamic Text Wrapping:** Prevents long texts or lengthy links from being truncated (`...`), dynamically adjusting line heights to keep everything perfectly readable.
* **Backup:** Click the "Backup" button to copy and save your objectives or paste and import saved objectives.

---

## 🛠️ Technical Details and API Solutions

During development, the addon's architecture overcame specific challenges of Blizzard's modern API to remain pure Lua:

* **Secure Link Interception:** Uses a hook in the global link system, intelligently handling the loss of focus from aggressive windows (such as the Grimoire/Achievements) to ensure insertion into the field without generating *Taint* errors in the interface.
* **Dynamic Row Management:** The interface calculates the height of each list element in real time using the `GetStringHeight()` method, adjusting the scroll container (`ScrollFrame`) proportionally.
* **Clean Persistence:** Data is saved in a structured way in a single global table per account, with automatic backward compatibility for old data created in previous versions of the addon.

---

## 🚀 How to Install

1. Download the repository as a `.ZIP` file (or clone the repository).
2. Extract the folder and make sure the main directory is named exactly `MyJourney`.
3. Move the `MyJourney` folder to your game's add-ons directory: World of Warcraft\_retail_\Interface\AddOns\
4. Launch World of Warcraft and make sure the add-on is enabled in the Add-ons list.

---

## 🎮 How to Use

1. Type /mj in the game chat or click the floating icon on the edge of the minimap to open or close the main window.
2. Click in the text box to focus the cursor, hold Shift and click on any item in your bags, your collection, or a shared link in the chat to insert it as a direct link.
3. Check the "Show only my objectives" box at the bottom to filter the list by your current character.

---

## 📝 License

This project is open source and available for personal use and modification under the MIT license. Feel free to contribute UI improvements or new data organization logic!
