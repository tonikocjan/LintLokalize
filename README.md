# LintLokalize

Validate localizations in your project.

## Installation

Build:

```bash
~ make build
swift build -c release --disable-sandbox
Building for production...
Build complete! (1.35s)
```

Install:

```bash
~ sudo make install
swift build -c release --disable-sandbox
Building for production...
Build complete! (0.10s)
install ".build/release/LintLokalize" "/usr/local/bin"
```

Make sure it is installed correctly:

```bash
~ which LintLokalize
/usr/local/bin/LintLokalize
```

## Basic usage

Navigate to the project directory:

```bash
~ cd MyProject/
```

Run `LintLokalize` and provide a path to the `*.strings` file:

```bash
MyProject/ ~ LintLokalize Resources/Localization/en.lproj/Localizable.string
1. Processing:  MyProject/File1.swift
2. Processing:  MyProject/File2.swift
3. Processing:  MyProject/File3.swift
MyProject/File3.swift:86:50: warning: Unknown key: localization_key1
MyProject/File3.swift:86:50: warning: Unknown key: localization_key2
4. Processing:  MyProject/File4.swift
5. Processing:  MyProject/File5.swift
6. Processing:  MyProject/File6.swift
7. Processing:  MyProject/File7.swift
8. Processing:  MyProject/File8.swift
MyProject/File8.swift:86:50: warning: Unknown key: localization_key3
❗️ Found 3 unresolved localizations!
```

## Integrate with XCode

To integrate `LintLokalize` into XCode, create a new Run Script:

```bash
if which LintLokalize > /dev/null; then
  LintLokalize Path/To/Localization/Localizable.strings
else
  echo "warning: LintLokalize not installed"
fi
```

XCode will automatically display warnings for all unknown localization keys.

## Advance usage

### Severity 

Instead of warnings, you can configure `LintLokalize` to output errors. Severity is controlled by the `--severity` option:

```bash
MyProject/ ~ LintLokalize Resources/Localization/en.lproj/Localizable.string --severity error
1. Processing:  MyProject/File1.swift
2. Processing:  MyProject/File2.swift
3. Processing:  MyProject/File3.swift
MyProject/File3.swift:86:50: error: Unknown key: localization_key1
MyProject/File3.swift:86:50: error: Unknown key: localization_key2
4. Processing:  MyProject/File4.swift
5. Processing:  MyProject/File5.swift
6. Processing:  MyProject/File6.swift
7. Processing:  MyProject/File7.swift
8. Processing:  MyProject/File8.swift
MyProject/File8.swift:86:50: error: Unknown key: localization_key3
❗️ Found 3 unresolved localizations!
```

When doing so, XCode will mark the build as failed if any localization is unresolved.

### Reporting style

`LintLokalize` supports two reporters, one for XCode and one intended for command line usage. You can switch the reporter using the `--reporter` option:


```bash
MyProject/ ~ LintLokalize Resources/Localization/en.lproj/Localizable.string --reported cmd
1. Processing:  MyProject/File1.swift
2. Processing:  MyProject/File2.swift
3. Processing:  MyProject/File3.swift
[50,86] MyProject/File3.swift: Unknown key: localization_key1
[50,86] MyProject/File3.swift: Unknown key: localization_key2
4. Processing:  MyProject/File4.swift
5. Processing:  MyProject/File5.swift
6. Processing:  MyProject/File6.swift
7. Processing:  MyProject/File7.swift
8. Processing:  MyProject/File8.swift
[50,86] MyProject/File8.swift: Unknown key: localization_key3
❗️ Found 3 unresolved localizations!
```
