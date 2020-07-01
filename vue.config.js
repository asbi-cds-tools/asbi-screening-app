const path = require('path');

module.exports = {
  configureWebpack: {
    module: {
      rules: [
        {
          test: /\.js$/,
          use: ["source-map-loader"],
          enforce: "pre",
          exclude: [
            path.resolve(__dirname, 'node_modules/cql-execution/lib'),
            path.resolve(__dirname, 'node_modules/fhirclient')
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
          test: /\.js\.map$/,
          use: ['ignore-loader']
        }
      ]
    }
  },
  publicPath: process.env.NODE_ENV === 'production'
    ? '/' + process.env.CI_PROJECT_NAME + '/'
    : '/',
  pages: {
    index: './src/main.js',
    launch: './src/launch.js'
  }
}