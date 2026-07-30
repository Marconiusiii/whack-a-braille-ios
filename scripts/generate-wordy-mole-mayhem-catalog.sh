#!/bin/zsh

set -euo pipefail

script_directory=${0:A:h}
repository_root=${script_directory:h}
source_path=${1:-"${repository_root}/../wordBop-iOS/WordBop/WordBop/words-en.txt"}
output_path=${2:-"${repository_root}/Whack A Braille/Resources/wordy-mole-mayhem-words-en.tsv"}
exclusion_path="${script_directory}/wordy-mole-mayhem-excluded-en.txt"
translator_path=${LOU_TRANSLATE_PATH:-/opt/homebrew/bin/lou_translate}

if [[ ! -f "${source_path}" ]]; then
	print -u2 "WordBopper iOS English word list not found: ${source_path}"
	exit 1
fi

if [[ ! -f "${exclusion_path}" ]]; then
	print -u2 "Wordy Mole Mayhem exclusion list not found: ${exclusion_path}"
	exit 1
fi

if [[ ! -x "${translator_path}" ]]; then
	print -u2 "Development-time UEB translator not found: ${translator_path}"
	exit 1
fi

temporary_directory=$(mktemp -d)
trap 'rm -rf "${temporary_directory}"' EXIT

candidate_path="${temporary_directory}/words.txt"
translated_path="${temporary_directory}/braille.txt"

LC_ALL=C awk '
	NR == FNR {
		if ($0 !~ /^#/ && $0 != "") {
			excluded[tolower($0)] = 1
		}
		next
	}
	{
		word = tolower($0)
		if (word ~ /^[a-z]+$/ && length(word) >= 4 && length(word) <= 10 && !excluded[word]) {
			print word
		}
	}
' "${exclusion_path}" "${source_path}" | LC_ALL=C sort -u > "${candidate_path}"

"${translator_path}" -f -d unicode.dis en-ueb-g2.ctb < "${candidate_path}" > "${translated_path}"

mkdir -p "${output_path:h}"

/usr/bin/ruby -e '
	words = File.readlines(ARGV[0], chomp: true)
	braille_lines = File.readlines(ARGV[1], chomp: true)
	abort("Translation count mismatch: #{words.length} words, #{braille_lines.length} translations") unless words.length == braille_lines.length

	File.open(ARGV[2], "w:utf-8") do |output|
		words.zip(braille_lines).each do |word, braille|
			masks = braille.codepoints.map do |codepoint|
				abort("Unexpected non-braille output for #{word}") unless (0x2801..0x28ff).cover?(codepoint)
				codepoint - 0x2800
			end
			abort("Empty UEB translation for #{word}") if masks.empty?
			output.puts("#{word}\t#{masks.join(",")}")
		end
	end
' "${candidate_path}" "${translated_path}" "${output_path}"

print "Generated $(wc -l < "${output_path}" | tr -d " ") Wordy Mole Mayhem entries at ${output_path}."
