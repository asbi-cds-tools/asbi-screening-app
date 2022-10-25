<template>
  <section v-show="getVersionString()" class="app__version"><div>Version <span v-html="getVersionString()"></span></div></section>
</template>

<script>
import { getEnv} from "../util/util.js";
export default {
  methods: {
      getVersionString() {
        return getEnv("VUE_APP_VERSION_STRING");
      }
  },
};
</script>
