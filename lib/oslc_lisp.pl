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
:- use_module(library(semweb/rdf11)).

:- multifile lisp:funct/3.

% TODO why is this commented out
% :- cp_after_load((
%   create_thread(oslc_client)
% )).

:- initialization((
  initialise_async(oslc_client_t, oslc_client_q)
  %, message_queue_create(_, [alias(oslc_client_retry_q)])
)).

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
  debug(lisp(oslc), '/async_client/ Initialising OSLC Client thread for async requests', []),
  % gtrace,
  repeat,
  thread_get_message(oslc_client_q, post_request(ResourceIRI, PostURI, Options)),
  post_wait_kb(ResourceIRI, PostURI, Options, 5),  
  % rdf
  

  % (thread_peek_message(oslc_client_q, post_request(ResourceIRI, PostURI, Options))
  %   -> (
  %     % send a message if it is ready
  %     thread_get_message(oslc_client_q, post_request(ResourceIRI, PostURI, Options)),
  %     % rdf
  %     catch_with_backtrace(
  %       oslc_client:post_resource(ResourceIRI, PostURI, Options),
  %       _, debug(lisp(oslc), 'Failed to POST resource to [~w]', [PostURI])
  %     )
  %   )
  %   ; (
      
  %   )
  fail.
  % true. % debug a single async notification

post_wait_kb(ResourceIRI, PostURI, Options, MaxRetries):-
  % debug(lisp(oslc), '/async_client/ Starting POST retries', []),
  post_retry_n(ResourceIRI, PostURI, Options, MaxRetries, 0).
  % debug(lisp(oslc), '/async_client/ Finished POST retries', []).


post_retry_n(ResourceIRI, _, _, MaxRetries, Retries) :-
  Retries >= MaxRetries, !,
  debug(lisp(oslc), '/async_client/ ~f retries exceeded to POST ~w', [MaxRetries, ResourceIRI]).

post_retry_n(ResourceIRI, PostURI, Options, MaxRetries, Retries) :-
  % trace,
  % debug(lisp(oslc), '/async_client/ Retry ~w for ~w', [Retries, ResourceIRI]),
  % catch_with_backtrace(
  %   (
  %     oslc_client:post_resource(ResourceIRI, PostURI, Options),
  %     debug(lisp(oslc), '/async_client/ POSTed after ~d KB read attempts', [Retries])
  %   ),
  %   _, debug(lisp(oslc), '/async_client/ Failed to POST resource to [~w]', [PostURI])).
  
  % (
  %   % rdf(ResourceIRI, _, _)
  %   rdf_subject(ResourceIRI)
  %   -> debug(lisp(oslc), '/async_client/ Resource ~w is present in default graph', [ResourceIRI])
  %   ; debug(lisp(oslc), '/async_client/ Resource ~w is MISSING FROM default graph', [ResourceIRI])
  % ),

  (
  rdf(ResourceIRI, _, _)
  % true
  % ->     debug(lisp(oslc), '/async_client/ POSTing ~w', [ResourceIRI])
  -> catch_with_backtrace(
    (
      oslc_client:post_resource(ResourceIRI, PostURI, Options)
      % , debug(lisp(oslc), '/async_client/ POSTed after ~d KB read attempts', [Retries])
    ),
    _, debug(lisp(oslc), '/async_client/ Failed to POST resource to [~w]', [PostURI]))
  ; (
    % debug(lisp(oslc), '/async_client/ Resource ~w is MISSING FROM default graph', [ResourceIRI])
    % ,
    % implemented using nanosleep syscall https://github.com/SWI-Prolog/swipl/blob/404d2b59d970f4c87f4f5a735eed82f6c85d2de3/src/os/pl-os.c#L3063
    % kernel will not busywait unless this thread is likely to be scheduled next https://0xax.gitbooks.io/linux-insides/content/Timers/linux-timers-7.html#implementation-of-the-nanosleep-system-call
    RetriesNext is Retries + 1,
    Delay is 0.00001 * RetriesNext, % simple 10us backoff
    % debug(lisp(oslc), '/async_client/ Sleeping ~f s', [Delay]),
    sleep(Delay),
    post_retry_n(ResourceIRI, PostURI, Options, MaxRetries, RetriesNext)
  )),
  true.


lisp:funct(send, [ResourceIRI, PostURI], true) :- !,
  debug(lisp(oslc), 'POSTing resource [~w] to [~w]', [ResourceIRI, PostURI]),
  oslc_client:post_resource(ResourceIRI, PostURI, []).

lisp:funct(send, [ResourceIRI, PostURI, Options], true) :- !,
  debug(lisp(oslc), 'POSTing resource [~w] to [~w]', [ResourceIRI, PostURI]),
  oslc_client:post_resource(ResourceIRI, PostURI, Options).

lisp:funct(send_async, [ResourceIRI, PostURI, Options], true) :- !,
  debug(lisp(oslc), 'POSTing resource async [~w] to [~w]', [ResourceIRI, PostURI]),
  % gtrace,
  % TODO copy the resource before the rule can clean up
  % TODO add a func with cleanup option
  thread_send_message(oslc_client_q, post_request(ResourceIRI, PostURI, Options)).

lisp:funct(send_graph, [GraphIRI, PostURI], true) :- !,
  debug(lisp(oslc), 'POSTing graph [~w] to [~w]', [GraphIRI, PostURI]),
  oslc_client:post_graph(GraphIRI, PostURI, []).

lisp:funct(send_graph, [GraphIRI, PostURI, Options], true) :- !,
  debug(lisp(oslc), 'POSTing graph [~w] to [~w]', [GraphIRI, PostURI]),
  oslc_client:post_graph(GraphIRI, PostURI, Options).
