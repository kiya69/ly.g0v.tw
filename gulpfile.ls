#!/usr/bin/env lsc -bc
require! child_process
require! async
require! <[gulp gulp-exec gulp-stylus]>
gutil = require 'gulp-util'
{protractor, webdriver} = require \gulp-protractor

livescript = require \gulp-livescript

gulp.task 'server' ->
  gulp.src './server/*.ls'
    .pipe livescript({+bare}).on 'error', gutil.log
    .pipe gulp.dest './server/'

const webdriver-path = './node_modules/.bin/webdriver-manager'

var webdriver-process, standalone-selenium-pid, http-server

webdriver-update = (cb) ->
  gutil.log "updating webdriver"
  child_process.spawn webdriver-path, <[update]>
    .once \close ->
      gutil.log "webdriver-update complete"
      cb!

webdriver-start = (cb) ->
  webdriver-process := child_process.spawn webdriver-path, <[start]>, stdio: [\ignore, \pipe, \ignore]
  webdriver-process.once \close ->
    gutil.log "webdriver-start complete"

  <- webdriver-process.stdout.on \data
  # webdriver won't die if selenium still running
  # so we have to kill selenium directly after protractor finish
  if it.toString! is /seleniumProcess.pid: (\d+)/
    standalone-selenium-pid := that.1
    gutil.log "Selenium Process ID: #{that.1}"
  # Wait server ready, hacky
  if it.toString! is /Started org.openqa.jetty.jetty.Server/
    webdriver-process.unref!
    gutil.log 'webdriver up'
    cb!

webdriver = (cb) ->
  async.series [webdriver-update, webdriver-start], cb

gulp.task \webdriver, webdriver

gulp.task \httpServer <[server]> ->
  {lyserver} = require \./server/app
  http-server := require \http .create-server lyserver!
  port = 3333
  http-server.listen port, ->
    console.log "Running on port #port"

gulp.task \protractor <[webdriver build httpServer]> ->
  gulp.src ["./test/e2e/app/*.ls"]
    .pipe protractor configFile: "./test/protractor.conf.ls"
    .on \error ->
      throw it

gulp.task 'test:e2e' <[protractor]> ->
  gutil.log "Kill Selenium (#{standalone-selenium-pid})"
  process.kill standalone-selenium-pid
  httpServer.close!

gulp.task 'protractor:sauce' <[build httpServer]> ->
  args =
    seleniumAddress: ''
    sauceUser: process.env.SAUCE_USERNAME
    sauceKey: process.env.SAUCE_ACCESS_KEY
    'capabilities.build': process.env.TRAVIS_BUILD_NUMBER
  if process.env.TRAVIS_JOB_NUMBER
    args['capabilities.tunnel-identifier'] = that

  gulp.src ["./test/e2e/app/*.ls"]
    .pipe protractor do
      configFile: "./test/protractor.conf.ls"
      args: args
    .on \error ->
      throw it

gulp.task 'test:sauce' <[protractor:sauce]> ->
  httpServer.close!

gulp.task 'build' <[template]> ->
  gulp.src 'package.json'
    .pipe gulp-exec 'bower i && ./node_modules/.bin/brunch b -P'
    .on \error ->
      throw it

gulp.task 'test:unit' <[build]> ->
  gulp.start 'test:karma'
  gulp.start 'test:util'

gulp.task 'test:karma' ->
  gulp.src 'package.json'
    .pipe gulp-exec './node_modules/karma/bin/karma start --browsers PhantomJS --single-run true test/karma.conf.ls'
    .on \error ->
      throw it

gulp.task 'test:util' ->
  gulp.src 'package.json'
    .pipe gulp-exec './node_modules/.bin/mocha --compilers ls:LiveScript test/unit/util'
    .on \error ->
      throw it

gulp.task 'dev' <[httpServer template]> ->
  require \brunch .watch {}, ->
    gulp.start 'test:karma'
    gulp.start 'test:util'
  gulp.watch 'app/partials/**/*.jade' <[template]>

require! <[gulp-angular-templatecache gulp-jade]>
gulp.task 'template' ->
  gulp.src 'app/partials/**/*.jade'
    .pipe gulp-jade!
    .pipe gulp-angular-templatecache 'app.templates.js' do
      base: process.cwd()
      filename: 'app.templates.js'
      module: 'app.templates'
      standalone: true
    .pipe gulp.dest '_public/js'

gulp.task 'ly-diff' <[ly-diff:js ly-diff:css]>

require! <[event-stream gulp-concat]>
gulp.task 'ly-diff:js' ->
  js = gulp.src 'app/diff.ls'
    .pipe livescript({+bare}).on 'error', gutil.log
  templates = gulp.src 'app/diff/diff.jade'
    .pipe gulp-jade!
    .pipe gulp-angular-templatecache do
      base: process.cwd()
      filename: 'app.templates.js'
      module: 'ly.diff'

  event-stream.merge js, templates
    .pipe gulp-concat 'ly-diff.js'
    .pipe gulp.dest '_public/js'

gulp.task 'ly-diff:css' ->
  gulp.src './app/styles/ly-diff.sass'
  .pipe gulp-stylus use: <[nib]>
  .pipe gulp.dest './_public/css'
