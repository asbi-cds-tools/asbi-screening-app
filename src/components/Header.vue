<template>
  <v-app-bar header color="background" elevation="1" app>
    <div class="logo-container mr-1">
      <img
        :src="getLogoSrc()"
        @load="handleImageLoaded"
        @error="handleImageLoaded"
      />
    </div>
    <v-toolbar-title
      class="text-h5 secondary--text font-weight-bold"
      v-text="title"
    ></v-toolbar-title>
    <div class="ml-6">
      <div
        class="text-subtitle-2 secondary--text text-overflow"
        v-if="hasPatientName()"
        v-text="getPatientName()"
      ></div>
      <div
        class="text-subtitle-2 secondary--text text-overflow"
        v-text="getPatientDob()"
      ></div>
    </div>
    <div v-if="getReturnURL()"><v-btn color="primary" :href="getReturnURL()" class="ml-4">Patient List</v-btn></div>
  </v-app-bar>
</template>

<script>
import { getEnv, imageOK } from "../util/util.js";
export default {
  props: {
    patient: Object,
    title: {
      type: String,
      default: "Assessment",
    },
  },
  methods: {
    getLogoSrc() {
      return `/${getEnv("VUE_APP_PROJECT_ID")}/img/logo.png`;
    },
    getReturnURL() {
      return getEnv('VUE_APP_DASHBOARD_URL');
    },
    handleImageLoaded(e) {
      if (!e.target) {
        return false;
      }
      let imageLoaded = imageOK(e.target);
      if (!imageLoaded) {
        e.target.classList.add("ghost");
        return;
      }
      e.target.classList.remove("ghost");
    },
    hasPatientName() {
      return this.patient && this.patient.name && this.patient.name.length;
    },
    getPatientName() {
      if (!this.hasPatientName()) return "";
      return [this.patient.name[0].family, this.patient.name[0].given[0]].join(
        ", "
      );
    },
    getPatientDob() {
      if (!this.patient || !this.patient.birthDate) return "";
      return this.patient.birthDate;
    },
  },
};
</script>
