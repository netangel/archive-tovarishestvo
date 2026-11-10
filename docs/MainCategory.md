# Main category (раздел)

Each drawing in the metadata JSON has one main category in `MainCategory`. The site groups drawings by it under `/razdely`.

## Where the value comes from

- **Processing** (`Convert-ScannedFIles.ps1`, `Initialize-MetadataOnProcessedScans.ps1`) never sets it.
  - New drawings get `"MainCategory": null`.
  - Existing values are kept. The rebuild script copies them from the old JSON by file hash.
- **`Set-MainCategory.ps1`** fills it. It is a separate step that you run by hand.
- **`ConvertTo-ZolaContent.ps1`** writes a non-empty value into each drawing page as the Zola taxonomy `razdely`.

## Categories and rules

`rules/main-categories.json` holds two lists:

- `Categories`: the 11 allowed names, in display order, with short descriptions. The site lists the same names in `config.toml` under `[extra] razdely`. Change both together.
- `Rules`: regular expressions, tried in order. The first match gives the category.
  - The text matched is `<folder name> | <file name without extension> | <tags>`.
  - Matching ignores case. Use `(?-i:...)` where case matters, for example `(?-i:Бот)`, which does not match «работа».

**Order is the policy:**

1. Shipyard tooling, such as dory production-line carts, dies and jigs, goes to «Верфь: оборудование и оснастка», even when it names a vessel.
2. A drawing that names a vessel goes to that vessel's class. A schooner's bunk is in «Шхуны», not in «Судовая мебель».
3. Supplementary categories (furniture, shipyard buildings and tools, ship equipment) take only drawings that name no vessel.

## Workflow

1. Make the report:
   ```powershell
   ./Set-MainCategory.ps1 -MetadataPath ../metadata -ReportPath ./main-category.csv
   ```
   - It has one row per drawing with an empty category.
   - `Source` is `rule` when a rule matched and `none` when nothing did. `Rule` shows which rule matched and the text it matched.
   - Add `-IncludeAssigned` to also list drawings that already have a value (`Source = json`).
2. Review the CSV. Fix `Proposed` where it is wrong. Leave it empty to keep the drawing without a category.
3. Write the values:
   ```powershell
   ./Set-MainCategory.ps1 -MetadataPath ../metadata -ApplyCsv ./main-category.csv
   ```
   - Only empty values are filled. Add `-Force` to overwrite existing ones.
   - An unknown name stops the run before anything is written.
   - The JSON is written the same way processing writes it, so the git diff shows only `MainCategory` lines.
4. Commit the metadata change and open a pull request.
