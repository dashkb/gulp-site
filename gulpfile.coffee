gulp       = require 'gulp'
gulpIf     = require 'gulp-if'
browserify = require 'gulp-browserify'
coffee     = require 'gulp-coffee'
uglify     = require 'gulp-uglify'
concat     = require 'gulp-concat'
gutil      = require 'gulp-util'
clean      = require 'gulp-clean'
less       = require 'gulp-less'
csso       = require 'gulp-csso'
marked     = require 'gulp-marked'
rename     = require 'gulp-rename'
mapStream  = require 'map-stream'
haml       = require 'gulp-haml'
fs         = require 'fs'
connect    = require 'connect'
fm         = require 'front-matter'
path       = require 'path'
slug       = require 'slug'
git        = require 'gift'

gulp.task 'layout', ->
  gulp.src('./src/**.haml')
    .pipe(haml())
    .pipe(gulp.dest './tmp')

gulp.task 'pages', ['layout'], ->
  markedOpts =

  layout       = fs.readFileSync './tmp/layout.html'
  nav          = fs.readFileSync './tmp/nav.html'
  pages        = {}
  

  gulp.src('./src/**/*.md')
    .pipe(mapStream (file, cb) ->
      # Extract front matter
      content = fm file.contents.toString 'utf8'
      pages[file.path] = content.attributes
      file.contents = new Buffer content.body
      cb null, file
    )
    .pipe(marked
      gfm: true
      tables: true
      smartypants: true
      smartLists: true
      highlight: (code) ->
        require('highlight.js').highlightAuto(code).value
    )
    .pipe(mapStream (file, cb) ->
      if file.isNull()
        cb null, file
      else if file.isStream()
        cb new Error "stream NYI"
      else
        dir  = path.dirname file.path
        base = path.basename file.path
        ext  = path.extname file.path

        file.path = "#{dir}/#{slug(pages[file.path].title).toLowerCase()}#{ext}"
        console.log file.path

        file.contents = new Buffer gutil.template layout,
          nav: nav
          content: file.contents.toString 'utf8'
          file: file
          title: 'A Page'

        cb null, file
    )
    .pipe(rename ext: '')
    .pipe(rename ext: '.html')
    .pipe(gulp.dest './build')

gulp.task 'bundle-coffee', ->
  gulp.src('./src/**/*.coffee')
    .pipe(coffee bare: true)
    .pipe(browserify())
    .pipe(concat 'bundle.js')
    .pipe(gulp.dest './tmp')

gulp.task 'bundle-less', ->
  gulp.src('./src/**/*.less')
    .pipe(concat 'bundle.less')
    .pipe(gulp.dest './tmp')

gulp.task 'js-deps', ->
  gulp.src([
    './bower_components/jquery/jquery.js',
    './bower_components/bootstrap/dist/js/bootstrap.js'
  ]).pipe(concat 'deps.js')
    .pipe(gulp.dest './tmp')

gulp.task 'copy-fonts', ->
  gulp.src('./bower_components/font-awesome/fonts/*')
    .pipe(gulp.dest './build/fonts')

gulp.task 'all-js', ['bundle-coffee', 'js-deps'], ->
  gulp.src([
    './tmp/deps.js',
    './tmp/bundle.js'
  ]).pipe(concat 'all.js')
    .pipe(gulpIf gulp.env.production, uglify())
    .pipe(gulp.dest './build/js')

gulp.task 'all-css', ['bundle-less', 'copy-fonts'], ->
  gulp.src([
    './tmp/bundle.less'
  ]).pipe(less())
    .pipe(concat 'all.css')
    .pipe(gulpIf gulp.env.production, csso())
    .pipe(gulp.dest './build/css')


gulp.task 'build-all', ['pages', 'all-css', 'all-js'], ->
  gulp.run 'clean-tmp'

gulp.task 'clean-tmp', ->
  gulp.src('./tmp').pipe clean()

gulp.task 'clean', ['clean-tmp'], ->
  gulp.src('./build').pipe clean()

gulp.task 'default', ['build-all']

gulp.task 'dev', ->
  connect()
    .use(connect.static('./build'))
    .listen(8080)

  gulp.watch './src/**/*.md', -> gulp.run 'pages'
  gulp.watch './src/**/*.haml', -> gulp.run 'layout'
  gulp.watch './src/**/*.coffee', -> gulp.run 'bundle-coffee'
  gulp.watch './src/**/*.less', -> gulp.run 'bundle-less'

  gulp.run 'build-all'
