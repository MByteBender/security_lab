set -e

# Get the absolute path to credentials
VARS_FILE="$(pwd)/credentials.pkrvars.hcl"
cd "modules"

for dir in */; do
    dir=${dir%/}

    # Skip hidden folders
    [[ "$dir" == .* ]] && continue

    echo "================================================"
    echo " CHECKING: $dir"
    echo "================================================"

    (
        cd "$dir"

        # IMPROVED CHECK:
        # 1. Check if any .pkr.hcl files exist
        # 2. Ensure they are actual files (-f)
        found_packer=false
        for f in *.pkr.hcl; do
            [ -f "$f" ] && found_packer=true && break
        done

        if [ "$found_packer" = true ]; then
            echo "Building Packer template in $dir..."
            packer init .
            packer build -var-file="$VARS_FILE" .
        else
            echo "Skipping $dir: No valid .pkr.hcl file found."
        fi
    )
done

echo "All detected builds are complete!"