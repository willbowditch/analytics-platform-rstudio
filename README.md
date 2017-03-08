# analytics-platform-rstudio

RStudio Docker image for Analytics Platform


## Tricks

### Find apt package with a certain file

RStudio may complain about some missing file. There is a command to find
the package containing the file:

```bash
$ apt-get install apt-file
$ apt-file update
$ apt-file search titling.sty
```

See: https://github.com/rstudio/rmarkdown/issues/359#issuecomment-253335365
