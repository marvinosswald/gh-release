
readonly ref_endpoint="${GITHUB_API_URL:-https://api.github.com}/repos/%s/git/refs/tags/%s"
readonly release_endpoint="${GITHUB_API_URL:-https://api.github.com}/repos/%s/releases"
readonly release_json='{"tag_name": "v%s", "name": "%s", "target_commitish": "%s"}'

release-create() {
	declare reponame="$1" version="${2#v}" branch="${3:-master}" name="$4"
	local release="$(printf "$release_json" "$version" "$name" "$branch")"
	local release_url="$(printf "$release_endpoint" "$reponame")"
	echo "Creating release v$version from branch $branch ..."
	upload_url="$(curl -s -d "$release" "$release_url?access_token=$GITHUB_ACCESS_TOKEN" | upload-url)"
	for asset in $(ls -A release); do
		local name="$(basename $asset)"
		echo "Uploading $name ..."
		curl -X POST -H "Content-Type: $(mimetype $name) name: $name" --data-binary "@release/$asset" \
			"$upload_url=$name&access_token=$GITHUB_ACCESS_TOKEN" > /dev/null
	done
}

release-destroy() {
	declare reponame="$1" version="$2"
	local release_url="$(printf "$release_endpoint" "$reponame")"
	release_id="$(curl -s "$release_url" | release-id-from-tagname "v$version")"
	echo "Deleting release..."
	curl -s -X DELETE "$release_url/$release_id?access_token=$GITHUB_ACCESS_TOKEN"
	echo "Deleting tag..."
	tag_url="$(printf "$ref_endpoint" "$reponame" "v$version")"
	curl -s -X DELETE "$tag_url?access_token=$GITHUB_ACCESS_TOKEN"
}

usage() {
	echo "Usage: gh-release [-v] subcommand"
	echo
	echo "Subcommands:"
	echo "  create <reponame> <version> [branch] [name]"
	echo "  destroy <reponame> <version>"
	echo "  checksums <algorithm>"
	echo
}

release-checksums() {
	declare alg="$1"
	echo "Writing $alg checksum files..."
	for asset in $(ls -A release); do
		cat "release/$asset" | checksum "$alg" > "release/${asset}.$alg"
	done
}

main() {
	set -eo pipefail; [[ "$TRACE" ]] && set -x
	case "$1" in
		create)		shift; release-create "$@";;
		destroy)	shift; release-destroy "$@";;
		checksums)	shift; release-checksums "$@";;
		-v)			echo "$VERSION";;
		*)			usage;;
	esac
}
