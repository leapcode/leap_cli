#
# This exists solely to prevent other gems we depend on from
# importing json/ext (e.g. require 'json').
#
# If json/ext is imported, json/pure cannot work, and we heavily
# rely on the specific behavior of json/pure.
#
# This trick only works if this directory is early in the
# include path.
#
require 'json/pure'
