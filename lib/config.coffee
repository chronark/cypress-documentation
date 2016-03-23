_        = require("lodash")
str      = require("underscore.string")
path     = require("path")
settings = require("./util/settings")

## cypress following by _
cypressEnvRe = /^(cypress_)/i

folders = "supportFolder fixturesFolder integrationFolder unitFolder".split(" ")

isCypressEnvLike = (key) ->
  cypressEnvRe.test(key) and key isnt "CYPRESS_ENV"

convertRelativeToAbsolutePaths = (projectRoot, obj) ->
  _.reduce folders, (memo, folder) ->
    if existing = obj[folder]
      memo[folder] = path.resolve(projectRoot, existing)

    return memo
  , {}

module.exports = {
  get: (projectRoot, options = {}) ->
    Promise.all([
      settings.read(projectRoot)
      settings.readEnv(projectRoot)
    ])
    .spread (settings, envFile) =>
      @set({
        projectRoot: projectRoot
        config:      settings
        envFile:     envFile
        options:     options
      })

  set: (obj = {}) ->
    {projectRoot, config, envFile, options} = obj

    ## just force config to be an object
    ## so we dont have to do as much
    ## work in our tests
    config ?= {}

    ## flatten the object's properties
    ## into the master config object
    config.envFile     = envFile
    config.projectRoot = projectRoot

    @mergeDefaults(config, options)

  mergeDefaults: (config = {}, options = {}) ->
    _.extend config, _.pick(options, "isHeadless", "socketId")

    if p = options.port
      config.port = p

    if e = options.environmentVariables
      config.environmentVariables = e

    if url = config.baseUrl
      ## always strip trailing slashes
      config.baseUrl = str.rtrim(url, "/")

    _.defaults config,
      morgan:         true
      baseUrl:        null
      socketId:       null
      isHeadless:     false
      clientRoute:    "/__/"
      xhrRoute:       "/xhrs/"
      socketIoRoute:  "/__socket.io"
      commandTimeout: 4000
      visitTimeout:   30000
      requestTimeout: 5000
      responseTimeout: 20000
      port:            2020
      waitForAnimations: true
      animationDistanceThreshold: 5
      autoOpen:       false
      viewportWidth:  1000
      viewportHeight: 660
      # unitFolder:        "cypress/unit"
      supportFolder:     "cypress/support"
      fixturesFolder:    "cypress/fixtures"
      integrationFolder: "cypress/integration"
      javascripts:    []
      namespace:      "__cypress"

    ## split out our own app wide env from user env variables
    ## and delete envFile
    config.environmentVariables = @parseEnv(config)
    config.env = process.env["CYPRESS_ENV"]
    delete config.envFile

    config = @setUrls(config)

    config = @setAbsolutePaths(config)

    return config

  setAbsolutePaths: (obj) ->
    obj = _.clone(obj)

    ## if we have a projectRoot
    if pr = obj.projectRoot
      _.extend obj, convertRelativeToAbsolutePaths(pr, obj)

    return obj

  setUrls: (obj) ->
    obj = _.clone(obj)

    rootUrl = "http://localhost:" + obj.port

    _.extend obj,
      clientUrlDisplay: rootUrl
      clientUrl:        rootUrl + obj.clientRoute
      xhrUrl:           obj.namespace + obj.xhrRoute

    return obj

  parseEnv: (cfg) ->
    envCfg  = cfg.env ? {}
    envFile = cfg.envFile ? {}
    envProc = @getProcessEnvVars(process.env) ? {}
    envCLI  = cfg.environmentVariables ? {}

    ## envCfg is from cypress.json
    ## envFile is from cypress.env.json
    ## envPRoc is from process env vars
    ## envCLI is from CLI arguments
    _.extend envCfg, envFile, envProc, envCLI

  getProcessEnvVars: (obj = {}) ->
    normalize = (key) ->
      key.replace(cypressEnvRe, "")

    _.reduce obj, (memo, value, key) ->
      if isCypressEnvLike(key)
        memo[normalize(key)] = value
      memo
    , {}

}