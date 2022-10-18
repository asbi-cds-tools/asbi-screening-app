import Vue from 'vue'
import Vuetify from 'vuetify'
import 'vuetify/dist/vuetify.min.css';
import themes from '../context/themes';
import {fetchEnvData, getEnv} from '../util/util';

const getAppTheme = () => {
    fetchEnvData();
    const projectID = String(getEnv("VUE_APP_PROJECT_ID")).toLowerCase();
    if (themes[projectID] && themes[projectID].app) return themes[projectID].app;
    return themes["default"].app;
};

Vue.use(Vuetify);
export default new Vuetify(getAppTheme());
