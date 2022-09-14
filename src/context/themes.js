import colors from "../../node_modules/vuetify/lib/util/colors";
export default {
  default: {
    app: {
      theme: {
        themes: {
          light: {
            primary: colors.teal,
            secondary: colors.blueGrey.darken4,
            background: colors.teal.lighten5,
            accent: colors.teal.darken4,
            error: colors.red.accent3,
          },
          dark: {
            primary: colors.teal.lighten5,
          },
        },
      },
    },
    survey: {
      "$main-color": colors.teal.darken2,
      "$main-hover-color": colors.teal.darken3,
      "$header-color": colors.teal.darken3,
    },
  },
  // project specific theme here
};
