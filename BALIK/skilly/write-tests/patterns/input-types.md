# Input Type Patterns

| Input | Method |
|-------|--------|
| Standard text | `fill()` |
| Autocomplete / typeahead | `pressSequentially({ delay })` + wait for suggestions |
| Native select / combobox | `selectOption()` |
| Checkbox / radio | `check()` / `setChecked()` |
| File upload | `setInputFiles()` |
| Date picker (native) | `fill('2024-01-15')` |
| Date picker (custom) | Inspect component — ask if unsure |
