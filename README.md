# PowerShell.tmLanguage
tmLanguage JSON file from VS Code for PowerShell language syntax scoping

This repository is for making adjustments to the PowerShell language grammer syntax scoping file used by VS Code, a JSON formatted file.

The purpose of the adjustments are to try making improvements in the scoping (and thus theming) of PowerShell script language documents while editing with VS Code.

The PowerShell/EditorSyntax repository is the official source of the VS Code tmLanguage document, but it is in the formal tmLanguage XML PList format.

I have made significant changes, based on PowerShell/EditorSyntax commit 472c944:
- improved ${} handling, including fixes to ${drive:variable}, doesn't scope out the escapes, accepts invalid ${\`}
- improved $var::static
- added meta.embedded scope to interpolation inside double quoted strings, most themes will revert back to base color for the interpolated text, plus it adds support for full intellisense inside the embedded expression.
- fixed some of the issues with '#' inside object names and file paths
- removed incorrect or redundant includes
- replaced base $() match with include "#interpolation" - should actually be called subexpression
- added "stringInterpolation" specifically for subexpressions in interpolation
- improved matching of $^ $$ and $?, still missing all ${_automatics_}

I am sure there are lots of new problems, along with tons that this doesn't fix yet.