import Vue from 'vue'
import Vuetify from 'vuetify'
import 'vuetify/dist/vuetify.min.css';
import themes from '../context/themes';


Vue.use(Vuetify);
export default new Vuetify(themes.app);
