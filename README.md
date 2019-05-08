# PowerShell.tmLanguage
tmLanguage JSON file from VS Code for PowerShell language syntax scoping

This repository is for making adjustments to the PowerShell language grammer syntax scoping file used by VS Code, a JSON formatted file.

The purpose of the adjustments are to try making improvements in the scoping (and thus theming) of PowerShell script language documents while editing with VS Code.

The PowerShell/EditorSyntax repository is the official source of the VS Code tmLanguage document, but it is in the formal tmLanguage XML PList format.

I have made significant changes, based on PowerShell/EditorSyntax commit 472c944:
- improved ${} handling, including fixes to ${drive:variable}, and multiline names, but accepts invalid ${\`}
- added meta.embedded scope to interpolation inside double quoted strings, most themes will revert back to base color for the interpolated text, plus it adds support for full intellisense inside the embedded expression.
- fixed some of the issues with '#' inside object names and file paths
- improved matching of $^ $$ and $?, still missing many ${_automatics_}

2019-02-02
- Now with improved class and function support and with enum support.
- Now with consistent 'accessor' (member/method/property/index) scoping behavior.
- Now with a full statement syntaxing approach, which limits keywords from scoping where they are not available.
- In many places, invalid text will be so marked.
- There are still issues being worked out, so some valid text/keywords may be marked as invalid.

For more information, reference [PowerShell/EditorSyntax PR #156](https://github.com/PowerShell/EditorSyntax/pull/156).  Changes made here are also being posted to that PR.

Included are some scripts for conversion of the JSON file to PList and CSON format, and for interogating the scopes used within the syntax.

I am sure there are lots of new problems, along with tons that this doesn't fix yet.
