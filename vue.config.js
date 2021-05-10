const path = require('path');

module.exports = {
  // chainWebpack: config => {
  //   // disable cache for prod only, remove the if to disable it everywhere
  //   // if (process.env.NODE_ENV === 'production') {
  //     config.module.rule('vue').uses.delete('cache-loader');
  //     config.module.rule('js').uses.delete('cache-loader');
  //     config.module.rule('ts').uses.delete('cache-loader');
  //     config.module.rule('tsx').uses.delete('cache-loader');
  //   // }
  // },
  transpileDependencies: [
    // can be string or regex
    'fhirclient',
    'survey-vue',
    'cql-execution',
    'cql-exec-fhir',
    'questionnaire-to-survey',
    'vue',
    'vue-loader',
    'vue-loader-v16',
    'vue-style-loader',
    'vue-template-compiler',
    'vue-template-es2015-compiler',
    'sax',
    'xmldoc',
    'body-parser',
    'debug',
    '@lhncbc/ucum-lhc'
  ],
  configureWebpack: {
    module: {
      rules: [
        {
          test: /\.js$/,
          use: ["source-map-loader"],
          enforce: "pre",
          exclude: [
            path.resolve(__dirname, 'node_modules/cql-execution/lib'),
            path.resolve(__dirname, 'node_modules/fhirclient'),
            path.resolve(__dirname, 'node_modules/cql-worker'),
            path.resolve(__dirname, 'node_modules/cql-exec-fhir')
          ]
        },
        {
          test: /\.worker\.js$/,
          use: { 
            loader: 'worker-loader',
            options: { 
              publicPath: '/src/cql/',
              inline: true 
            }
          }
        },
        {
          test: /CqlProcessor\.js$/,
          use: ['babel-loader']
        },
        {
          test: /main\.js$/,
          use: ['babel-loader']
        },
        {
          test: /\.js\.map$/,
          use: ['ignore-loader']
        },
        {
          test: /\.0\.0\.xml\.js$/,
          use: ['ignore-loader']
        }
      ]
    }
  },
  publicPath: process.env.NODE_ENV === 'production'
    ? '/asbi-screening-app/'
    : '/',
  pages: {
    index: './src/main.js',
    launch: './src/launch.js'
  }
}