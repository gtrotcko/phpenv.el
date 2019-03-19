# phpenv.el

phpenv.el ia an Emacs extension which integrates the editor with [phpenv](https://github.com/phpenv/phpenv "phpenv/phpenv").

Disclaimer
----------
This repository is a fork of the [rbenv.el](https://github.com/senny/rbenv.el 
"senny/rbeny.el") project. Please don't ask me anything, I do not even know 
Emacs Lisp well enough to create something new. I only heve edited original 
rbeny.el and README replacing all mentions of the Ruby and Rbenv with PHP and Phpenv. 
The main purpose of this repository is my personal using and for me it works well.


Installation
------------

```lisp
(add-to-list 'load-path "~/.emacs.d/site-lisp/")
(require 'phpenv)
(global-phpenv-mode)
```

Usage
-----

* `global-phpenv-mode` activate / deactivate phpenv.el (The current PHP version is shown in the modeline)
* `phpenv-use-global` will activate your global PHP
* `phpenv-use` allows you to choose what PHP version you want to use
* `phpenv-use-corresponding` searches for .php-version and activates
the corresponding PHP

Configuration
-------------

**phpenv installation directory**
By default phpenv.el assumes that you installed phpenv into
`~/.phpenv`. If you use a different installation location you can
customize phpenv.el to search in the right place:

```lisp
(setq phpenv-installation-dir "/usr/local/phpenv")
```

*IMPORTANT:*: Currently you need to set this variable before you load phpenv.el

**the modeline**
phpenv.el will show you the active PHP in the modeline. If you don't
like this feature you can disable it:

```lisp
(setq phpenv-show-active-php-in-modeline nil)
```

The default modeline representation is the PHP version (colored red) in square
brackets. You can change the format by customizing the variable:

```lisp
;; this will remove the colors
(setq phpenv-modeline-function 'phpenv--modeline-plain)
```

You can also define your own function to format the php version as you like.

Credit
-----
This extension is a fork of the [rbenv.el](https://github.com/senny/rbenv.el
"Rbenv on Github") extension. In fact I only have replaced all ruby and rbenv
mentions with php.
