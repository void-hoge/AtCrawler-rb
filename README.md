# AtcrawlerRb
- A tool to collect code submited to AtCoder in Ruby.

## Installation
- `gem build ./atcrawler_rb.gemspec`
- `gem install ./atcrawler_rb-0.1.0.gem`

## Usage
```
$ atcrawler_rb --help
Usage: atcrawler_rb (init|crawl) [options]
    -c, --contest CONTEST            Specify the AtCoder contest.
    -u, --username USERNAME          Specify the username to collect submission codes.
    -l, --language LANGUAGE          Specify the language of the code to be collected.
    -t, --task TASK                  Specify the task of the code to be collected. ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]
    -r, --result RESULT              Specify the result of the code to be collected. ["AC", "RE", "WA", "TLE", "MLE", "CE", "QLE", "OLE", "IE", "WJ", "WR", "Judging"]
    -o, --orderby ORDERBY            Specify the ordering method of the submission. ["created", "score", "source_length", "time_consumption", "memory_consumption"]
    -d, --descending                 Specify if in descending order.
    -m MAXSUBMISSIONS,               Specify the max submissions to collet.
        --maxsubmissions
$
```
- When in `init` mode, a contest environment is initialized.
  - Initialize the directory and download the input/output samples.
- When in `crawl` mode, a contest environment is initialized and submitted codes are collected.
  - Filters
	- username
	- language
	- task
	- result
  - Ordering methods
	- created time
	- score
	- source code length
	- time consumption
	- memory consumption
	- (reverse)

## License
- MIT

## Author
- Mugi Noda (void-hoge)
