<div align="center">

![J++ Logo](editors/vscode/icons/jpp-logo-128.svg)

# J++ Programming Language

> A systems programming language designed for kernel/OS development with AMD XDNA NPU support and hardware generation.

[![J++ CI](https://github.com/linuxab/jpp/actions/workflows/ci.yml/badge.svg)](https://github.com/linuxab/jpp/actions)
[![SPARK Verified](https://img.shields.io/badge/SPARK-Silver-blue.svg)](https://github.com/linuxab/jpp)
[![License: BSD clause 2.0 Licence](https://img.shields.io/badge/License-BSD2.0-yellow.svg)](LICENSE)
[![VS Code Extension](https://img.shields.io/badge/VS%20Code-Extension-007ACC.svg)](https://marketplace.visualstudio.com/items?itemName=linuxab.jpp-language)

</div>

# Adding J++ to GitHub Linguist

GitHub uses [Linguist](https://github.com/github/linguist) to detect languages and show icons.


## Steps to add J++ support:

### 1. Fork github/linguist
```bash
git clone https://github.com/github/linguist.git
cd linguist
```

### 2. Add language entry
Edit `lib/linguist/languages.yml` and add:

```yaml
J++:
  type: programming
  color: "#3a6ea5"
  aliases:
    - jpp
    - j++
  extensions:
    - ".jpp"
    - ".j++"
    - ".ph1"
    - ".pha"
    - ".yagmai"
  tm_scope: source.jpp
  ace_mode: c_cpp
  codemirror_mode: clike
  codemirror_mime_type: text/x-c++src
  language_id: 999999  # GitHub will assign this
```

### 3. Add grammar
```bash
# Copy our TextMate grammar
mkdir -p vendor/grammars/jpp-tmLanguage
cp editors/vscode/syntaxes/jpp.tmLanguage.json vendor/grammars/jpp-tmLanguage/

# Register in grammars.yml
echo "vendor/grammars/jpp-tmLanguage:\n  source.jpp:" >> grammars.yml
```

### 4. Add samples
```bash
mkdir -p samples/J++
cp examples/*.jpp samples/J++/
cp examples/*.yagmai samples/J++/ 2>/dev/null || true
```

### 5. Add heuristics (if needed)
Edit `lib/linguist/heuristics.yml` if J++ files need special detection.

### 6. Test locally
```bash
bundle install
bundle exec rake samples
bundle exec ruby test/test_classifier.rb
```

### 7. Submit PR
```bash
git add .
git commit -m "Add J++ programming language support"
git push origin add-jpp-language
```

Then create a PR to `github/linguist` with:
- Description of J++ language
- Link to this repo
- Usage statistics (if available)
- Sample files

## After Merge

Once merged, GitHub will:
- Show `.jpp` files with J++ label
- Apply syntax highlighting
- Show language stats in repo bar
- Display the J++ icon (when icon support is added)
