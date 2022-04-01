import Vue from 'vue'
import Vuetify from 'vuetify'
import 'vuetify/dist/vuetify.min.css';
import colors from 'vuetify/lib/util/colors';


Vue.use(Vuetify);

const opts = {
    theme: {
      themes: {
        light: {
          primary: colors.teal,
          secondary: colors.blueGrey.darken2,
          accent: colors.teal.darken4,
          error: colors.red.accent3,
        },
        dark: {
          primary: colors.teal.lighten5,
        },
      },
    },
};

export default new Vuetify(opts);
