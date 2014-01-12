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

gulp.task 'layout', ->
  gulp.src('./src/layout.haml')
    .pipe(haml())
    .pipe(gulp.dest './tmp')

gulp.task 'pages', ['layout'], ->
  markedOpts =
    gfm: true
    tables: true
    smartypants: true
    smartLists: true
    highlight: (code) ->
      require('highlight.js').highlightAuto(code).value

  layout  = fs.readFileSync './tmp/layout.html'
  nav     = fs.readFileSync './tmp/nav.html'

  layout = fs.readFileSync './tmp/layout.html'
  applyLayout = mapStream (file, cb) ->
    if file.isNull()
      cb null, file
    else if file.isStream()
      cb new Error "stream NYI"
    else
      file.contents = new Buffer gutil.template layout,
        content: file.contents.toString 'utf8'
        file: file
        title: 'A Page'

      cb null, file

  gulp.src('./src/**/*.md')
    .pipe(marked markedOpts)
    .pipe(rename ext: '')
    .pipe(rename ext: '.html')
    .pipe(applyLayout)
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

gulp.task 'css-deps', ->
  gulp.src([
    './bower_components/bootstrap/less/bootstrap.less'
  ]).pipe(less())
    .pipe(concat 'deps.css')
    .pipe(gulp.dest './tmp')

gulp.task 'all-js', ['bundle-coffee', 'js-deps'], ->
  gulp.src([
    './tmp/deps.js',
    './tmp/bundle.js'
  ]).pipe(concat 'all.js')
    .pipe(gulpIf gulp.env.production, uglify())
    .pipe(gulp.dest './build')

gulp.task 'all-css', ['bundle-less', 'css-deps'], ->
  gulp.src([
    './tmp/deps.css',
    './tmp/bundle.less'
  ]).pipe(concat 'all.less')
    .pipe(less())
    .pipe(gulpIf gulp.env.production, csso())
    .pipe(gulp.dest './build')


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
