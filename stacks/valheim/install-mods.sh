#!/bin/bash
# Installs the Thunderstore packages in VALHEIM_MODS into /config/bepinex/plugins,
# which the image syncs into the server after bootstrap.
#
# Runs as POST_BOOTSTRAP_HOOK, so only on container start.
# Each package lands in plugins/<Namespace-Name>/ with a .thunderstore-version marker,
# and is fetched again only when its version changes.
set -euo pipefail

plugins=/config/bepinex/plugins
mkdir -p "$plugins"

declare -A wanted

# Namespace-Name-Version, the form Thunderstore writes dependency strings in.
for mod in ${VALHEIM_MODS:-}; do
  package=${mod%-*}
  version=${mod##*-}
  dir=$plugins/$package
  wanted[$package]=1

  if [[ -f $dir/.thunderstore-version && $(<"$dir/.thunderstore-version") == "$version" ]]; then
    continue
  fi

  echo "install-mods: installing $package $version"

  # Downloaded before the old version is removed, so a failed fetch leaves it in place.
  zip=$(mktemp)
  curl -fsSL -o "$zip" "https://thunderstore.io/package/download/${package/-//}/$version/"
  rm -rf "$dir"
  mkdir -p "$dir"
  unzip -q "$zip" -d "$dir"
  rm -f "$zip"
  echo "$version" > "$dir/.thunderstore-version"
done

# Packages dropped from the list.
# Only directories with a marker, so plugins placed by hand are left alone.
for marker in "$plugins"/*/.thunderstore-version; do
  [[ -e $marker ]] || continue
  dir=${marker%/*}
  package=${dir##*/}

  if [[ -z ${wanted[$package]:-} ]]; then
    echo "install-mods: removing $package"
    rm -rf "$dir"
  fi
done
