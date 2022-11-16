//surveyJS object options, can be customized for a specific questionnaire by id
export default {
  default: {
    showQuestionNumbers: "off",
    showClearButton: true,
    completeText: "Submit",
    clearInvisibleValues: "onHidden",
    requiredText: "",
    completedHtml:
      "<h3>The screening is complete.</h3><h3>You may now close the window.</h3>",
  },
  MINICOG: {
    focusFirstQuestionAutomatic: true,
    checkErrorsMode: "onValueChanged",
    textUpdateMode: "onTyping",
    //validation
    questionValidator: function (survey, options) {
      const QUESTION1_ID = "minicog-question1";
      const QUESTION2_ID = "minicog-question2";
      const optionVal = parseInt(options.value);
      if (options.name === QUESTION1_ID) {
        if (optionVal > 3 || optionVal < 0) {
          options.error = "The value must be between 0 and 3.";
        }
      }
      if (options.name === QUESTION2_ID) {
        if (optionVal < 0 || optionVal > 2 || optionVal === 1) {
          options.error = "The value must be 0 or 2.";
        }
      }
    },
  },
  SLUMS: {
    focusFirstQuestionAutomatic: true,
    checkErrorsMode: "onValueChanged",
    //validation
    questionValidator: function (survey, options) {
      const SCORE_QUESTION_ID = "/71492-3";
      const optionVal = parseInt(options.value);
      if (options.name === SCORE_QUESTION_ID) {
        if (optionVal > 30 || optionVal < 1) {
          options.error = "The value must be between 1 and 30.";
        }
      }
    },
  },
};
