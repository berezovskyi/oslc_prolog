/*
Copyright 2019-2020 Ericsson AB

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

:- module(oslc_lisp, []).

:- use_module(library(oslc_client)).

:- multifile lisp:funct/3.

% TODO why is this commented out
% :- cp_after_load((
%   create_thread(oslc_client)
% )).

% TODO refactor with rules.pl
initialise_async(Alias, QueueAlias) :-
   ( thread_property(_, alias(Alias))
   -> true
    ; thread_create(Alias, _, [alias(Alias)])
   ),
   ( message_queue_property(_, alias(QueueAlias))
   -> true
    ; message_queue_create(QueueAlias, [alias(QueueAlias)])
   ).

oslc_client_t :- 
  debug(lisp(oslc), 'Initialising OSLC Client thread for async requests', []),
  % gtrace,
  repeat,
  thread_get_message(oslc_client_q, post_request(ResourceIRI, PostURI, Options)),
  catch_with_backtrace(
    oslc_client:post_resource(ResourceIRI, PostURI, Options),
    _, debug(lisp(oslc), 'Failed to POST resource to [~w]', [PostURI])
  ),
  fail.

lisp:funct(send, [ResourceIRI, PostURI], true) :- !,
  debug(lisp(oslc), 'POSTing resource [~w] to [~w]', [ResourceIRI, PostURI]),
  oslc_client:post_resource(ResourceIRI, PostURI, []).

lisp:funct(send, [ResourceIRI, PostURI, Options], true) :- !,
  debug(lisp(oslc), 'POSTing resource [~w] to [~w]', [ResourceIRI, PostURI]),
  oslc_client:post_resource(ResourceIRI, PostURI, Options).

lisp:funct(send_async, [ResourceIRI, PostURI, Options], true) :- !,
  debug(lisp(oslc), 'POSTing resource [~w] to [~w]', [ResourceIRI, PostURI]),
  % gtrace,
  initialise_async(oslc_client_t, oslc_client_q),
  % TODO copy the resource before the rule can clean up
  % TODO add a func with cleanup option
  thread_send_message(oslc_client_q, post_request(ResourceIRI, PostURI, Options)).

lisp:funct(send_graph, [GraphIRI, PostURI], true) :- !,
  debug(lisp(oslc), 'POSTing graph [~w] to [~w]', [GraphIRI, PostURI]),
  oslc_client:post_graph(GraphIRI, PostURI, []).

lisp:funct(send_graph, [GraphIRI, PostURI, Options], true) :- !,
  debug(lisp(oslc), 'POSTing graph [~w] to [~w]', [GraphIRI, PostURI]),
  oslc_client:post_graph(GraphIRI, PostURI, Options).
