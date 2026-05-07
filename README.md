# Inventori

Inventori is a simple web application that allows users to create simple lists of gear, organizing them into main categories, sub-categories, and individual items. Users can increment or decrement the count of items as needed, rename the inventory list, and export the list as a JSON file.


[![Netlify Status](https://api.netlify.com/api/v1/badges/77991343-af4e-4913-be94-f1789ca2981d/deploy-status)](https://app.netlify.com/sites/glittery-puffpuff-043120/deploys)

## Features

- Organize inventory items into main categories and sub-categories
- Add or subtract item quantities easily
- Rename the inventory list
- Export the inventory list as a JSON file
- Clear the inventory list
- Responsive design for use on mobile devices
- Sha256 hash map of list data embedded into list to add some guarantees about list provenance
- Prevents duplicate imports using a hash of imorted files
- Consolidates multiple lists into one count
- Prevents lists of two different types from being added together

## In Progress

- Import Rental House Order for Checkout
- Create Document to Submit Order for Rental House
- Import/Checkout
- QR code sheet generator
- In-Browser Editable source list
- Metadata Tagging of Already Populated Counts (for logistics tracking)
- Export CSV
- Export PDF
- Item information Encoded into a QR Code

## How to Use

1. Select a main category, sub-category, and item from the dropdown menus.
2. Use the `+` and `-` buttons to add or subtract the quantity of the selected item.
3. Click the "Rename" button to change the name of the inventory list.
4. Click the "Clear List" button to clear the entire inventory list.
5. Click the "Export List as JSON" button to download the inventory list as a JSON file.


## Nix Deployment

To run the Inventory App locally, run.

```bash
git clone https://github.com/harryprayiv/inventoryTS.git
cd inventoryTS
nix run .#live-server

```

## Installation and Deployment for Non-Nix People

To run the Inventory App locally, clone this repository and open the `index.html` file in a web browser.

```bash
git clone https://github.com/harryprayiv/inventoryTS.git
cd inventoryTS

```





