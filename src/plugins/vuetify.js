import Vue from 'vue'
import Vuetify from 'vuetify'
import 'vuetify/dist/vuetify.min.css';
import themes from '../context/themes';
import {getEnv} from '../util/util';

const getAppTheme = () => {
    const projectID = getEnv("VUE_APP_PROJECT_ID");
    if (themes[projectID] && themes[projectID].app) return themes[projectID].app;
    return themes["default"].app;
};

Vue.use(Vuetify);
export default new Vuetify(getAppTheme());
