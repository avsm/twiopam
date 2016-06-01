## This Week in OPAM

Generates a summary Markdown report of the recent package updates 
to an OPAM repository.

### Usage

```
$ docker run -v `pwd`/out:/out avsm/twiopam
```

And a report will be generated in the `out/` directory.
For more options, try:

```
$ docker run avsm/twiopam --help
```
