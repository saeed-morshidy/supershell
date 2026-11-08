# toml-merge.awk — add the keys of OVERLAY to BASE without changing anything BASE sets.
#   awk -f toml-merge.awk OVERLAY BASE  >merged.toml
# Supports what starship configs use: [table] / [a.b] headers, single-line `key = value`
# and multi-line """…""" / '''…''' strings. For each table of OVERLAY, keys BASE lacks
# are added at the end of BASE's table; tables BASE lacks are appended whole.
# Comments and blank lines of OVERLAY are dropped. BASE is printed unchanged otherwise.

function is_header(l)  { return l ~ /^[ \t]*\[[^\]]+\][ \t]*$/ }
function hname(l)      { gsub(/^[ \t]*\[|\][ \t]*$/, "", l); gsub(/[ \t]/, "", l); return l }
function keyof(l,  k)  {          # bare, "quoted" or 'quoted' key (e.g. "$schema", "My Docs")
  if (!match(l, /^[ \t]*("[^"]*"|'[^']*'|[A-Za-z0-9_.-]+)[ \t]*=/)) return ""
  k = substr(l, 1, RLENGTH); sub(/[ \t]*=$/, "", k); gsub(/^[ \t]+/, "", k); return k
}
function opens_ml(l,  v, n, m) {   # value starts a multi-line string that does not close on this line
  v = l; sub(/^[^=]*=/, "", v)
  n = gsub(/"""/, "&", v); m = gsub(/'''/, "&", v)
  return (n % 2 == 1) ? "\"\"\"" : (m % 2 == 1) ? "'''" : ""
}
function flush(sec,  i, k) {       # print overlay keys of `sec` that base did not have
  for (i = 1; i <= ocount[sec]; i++) { k = okey[sec, i]; if (!((sec, k) in seen)) printf "%s", otext[sec, k] }
  done[sec] = 1
}

FNR == NR {                        # ---- read OVERLAY
  if (oml != "") { otext[osec, ocur] = otext[osec, ocur] $0 "\n"; if (index($0, oml)) oml = ""; next }
  if ($0 ~ /^[ \t]*(#|$)/) next
  if (is_header($0)) { osec = hname($0); if (!(osec in ohas)) { ohas[osec] = 1; order[++nsec] = osec }; next }
  ocur = keyof($0); if (ocur == "") next
  if (!((osec, ocur) in otext)) okey[osec, ++ocount[osec]] = ocur
  otext[osec, ocur] = $0 "\n"; oml = opens_ml($0)
  next
}
{                                  # ---- stream BASE (blank lines held back so
  if (bml != "") { print; if (index($0, bml)) bml = ""; next }   # additions stay inside the table)
  if ($0 ~ /^[ \t]*$/) { blanks = blanks $0 "\n"; next }
  if (is_header($0)) { flush(bsec); printf "%s", blanks; blanks = ""; bsec = hname($0); print; next }
  printf "%s", blanks; blanks = ""
  k = keyof($0); if (k != "") { seen[bsec, k] = 1; bml = opens_ml($0) }
  print
}
END {
  flush(bsec); printf "%s", blanks
  for (i = 1; i <= nsec; i++) {
    s = order[i]; if (s in done) continue
    if (s != "") printf "\n[%s]\n", s
    flush(s)
  }
}
