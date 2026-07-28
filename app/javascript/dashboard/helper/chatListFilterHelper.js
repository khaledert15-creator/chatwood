import wootConstants from 'dashboard/constants/globals';

const SUPPORTED_CONVERSATION_STATUSES = Object.values(
  wootConstants.STATUS_TYPE
);

export const getSupportedConversationStatus = status =>
  SUPPORTED_CONVERSATION_STATUSES.includes(status)
    ? status
    : wootConstants.STATUS_TYPE.OPEN;

export const initializeConversationStatus = (filterBy, updateUISettings) => {
  const status = getSupportedConversationStatus(filterBy.status);

  if (Object.hasOwn(filterBy, 'status') && filterBy.status !== status) {
    updateUISettings({
      conversations_filter_by: {
        ...filterBy,
        status,
      },
    });
  }

  return status;
};
