#!/bin/bash

set -euo pipefail

parse_block() {
  local type="$1"
  awk -v type="$type" '
    BEGIN {in_block=0}
    {
      if ($0 ~ type) {in_block=1; next}
      if (in_block && $0 ~ /^\[INFO\]/ && $0 !~ type) {in_block=0}
      if (in_block && $1 !~ /^\[INFO\]/) print $0
    }' "$ANALYZE_FILE" | grep -v '^\s*$' | sort | uniq
}

parse_tree_file() {
  local tree_file="$1"
  local temp_dir="$2"
  awk -v temp_dir="$temp_dir" '
    # Catch start of dependency:tree for each module
    /\[INFO\] --- dependency:[^ ]+:tree .* @ / {
      # extract artifactId
      match($0, / @ ([^ ]+) ---/, arr)
      module = arr[1]
      file = temp_dir "/" module ".tree"
      print ">>> Writing " file > "/dev/stderr"
      in_tree = 1
      next
    }

    # end of tree – new module or empty INFO block
    /\[INFO\] -------------------< / {
      in_tree = 0
    }

    # Content of the tree
    in_tree && /^\[INFO\] / {
      # remove [INFO] prefix
      sub(/^\[INFO\] /, "")
      print >> file
    }
  ' "$tree_file"
}

parse_dependency_file() {
  local dep_file="$1"
  local temp_dir="$2"
  awk -v temp_dir="$temp_dir" '
    # Catch start of dependency:tree for each module
    /\[INFO\] --- dependency:[^ ]+:analyze .* @ / {
      # extract artifactId
      match($0, / @ ([^ ]+) ---/, arr)
      module = arr[1]
      file = temp_dir "/" module ".dependency"
      print ">>> Writing " file > "/dev/stderr"
      in_tree = 1
      next
    }

    # end of tree – new module or empty INFO block
    /\[INFO\]/ {
      in_tree = 0
    }

    # Content of the tree
    in_tree && /^\[WARNING\] / {
      # remove [WARNING] prefix
      sub(/^\[WARNING\] /, "")
      print >> file
    }
  ' "$dep_file"
}

enrich_dependencies() {
  TREE_FILE="$1"
  DEP_FILE="$2"

  awk -v TREE="$TREE_FILE" '
    # Load tree file a build resolved[GA]
    BEGIN {
      while ((getline line < TREE) > 0) {
          if (line ~ /^$/) continue

          # depth based on |  before dependency
          depth = 0
          tmp = line
          while (tmp ~ /^\|  /) {
              sub(/^\|  /, "", tmp)
              depth++
          }

          # remove +- and spaces in the beginning of the line
          sub(/^[^a-zA-Z0-9]*/, "", tmp)

          # extract GA
          split(tmp, a, ":")
          ga = a[1] ":" a[2]

          stack[depth] = ga

          # build path
          path = ""
          for (i = 0; i < depth; i++) {
              if (stack[i] != "") path = path stack[i] " -> "
          }
          sub(/ -> $/, "", path)
          resolved[ga] = path
      }
    }

    # Read dependency file
    {
      # Start of Used undeclared section
      if ($0 ~ /^Used undeclared dependencies found:/) {
          in_used = 1
          print $0
          next
      }

      # when we are in Used undeclared section
      if (in_used) {
          # section ends when line starts with no space or EOF
          if ($0 !~ /^[[:space:]]/) {
              in_used = 0
          }
      }

      # process line Used undeclared
      if (in_used && $0 ~ /^[[:space:]]+[a-zA-Z0-9]/) {
          line = $0
          sub(/^[[:space:]]+/, "", line)
          split(line, a, ":")
          ga = a[1] ":" a[2]

          printf "  %s", line
          if (ga in resolved && resolved[ga] != "")
              printf "  (%s)", resolved[ga]
          print ""
          next
      }

      # all other lines are printed without modification
      print $0
    }
  ' "$DEP_FILE"
}

echo "Analyzing all modules in multi-module project..."
echo "-----------------------------------------------"

TMP_DIR=$(mktemp -d)
TREE_FILE="${TMP_DIR}/tree.txt"
ANALYZE_FILE="${TMP_DIR}/analyze.txt"

mvn dependency:tree -Dverbose > "$TREE_FILE"
mvn dependency:analyze > "$ANALYZE_FILE"

parse_tree_file ${TREE_FILE} ${TMP_DIR}
parse_dependency_file ${ANALYZE_FILE} ${TMP_DIR}

for f in ${TMP_DIR}/*.dependency; do
  base=$(basename "$f")
  echo
  echo ${base/.dependency/ module:}
  enrich_dependencies "${f/.dependency/.tree}" "${f}"
done

rm -rf "${TMP_DIR}"
