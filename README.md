## Comprun-C
#### Compiles, Runs (and awesomes)

If your writing a program, you might now want to save, compile, run, repeat...
so this script handles that for you. It will even pipe other commands into your
script or watch for when you save your script and then re-compile, re-pipe a
command, and print the results to your screen.


```sh
  $ screen -t "Screen with VIM" vim ./some-file.c
  $ CTRL-A, C
  $ CTRL-A, |
  $ CTRL-A, A
```
