# This file contains extensions to PAST for integration with 6model.

.namespace [ 'PAST';'Var' ]

=item type([value])

Accessor method -- sets/returns the type object for the type that this
will evaluate to. Note that this really is the type object itself, not
some PAST that will produce it or a name that it can be looked up by.

=cut

.sub 'type' :method
    .param pmc value           :optional
    .param int has_value       :opt_flag
    .tailcall self.'attr'('type', value, has_value)
.end

.namespace [ 'PAST';'Compiler' ]

.loadlib 'nqp_ops'

.sub '' :anon :load :init
    # Add some extra op signatures.
    .local pmc piropsig
    piropsig = get_global '%piropsig'
    piropsig['repr_get_attr_int'] = 'IPPs'
    piropsig['repr_bind_attr_int'] = 'vPPsi'
    piropsig['repr_get_attr_num'] = 'NPPs'
    piropsig['repr_bind_attr_num'] = 'vPPsn'
    piropsig['repr_get_attr_str'] = 'SPPs'
    piropsig['repr_bind_attr_str'] = 'vPPss'
.end

.const int STORAGE_SPEC_BP_INT = 1
.const int STORAGE_SPEC_BP_NUM = 2
.const int STORAGE_SPEC_BP_STR = 3

.sub 'attribute_6model' :method :multi(_, ['PAST';'Var'])
    .param pmc node
    .param pmc bindpost

    .local pmc ops
    $P0 = get_hll_global ['POST'], 'Ops'
    ops = $P0.'new'('node'=>node)
    .local string name
    name = node.'name'()
    name = self.'escape'(name)
    
    # See if we have a type. If so, use it to determine what op to use
    # and what the register type will be.
    .local pmc type
    .local string get_attr_op, set_attr_op, coerce_reg_type
    .local int primitive_type_id
    type = node.'type'()
    primitive_type_id = repr_get_primitive_type_spec type
    if primitive_type_id == STORAGE_SPEC_BP_INT goto prim_int
    if primitive_type_id == STORAGE_SPEC_BP_NUM goto prim_num
    if primitive_type_id == STORAGE_SPEC_BP_STR goto prim_str
    get_attr_op = 'getattribute'
    set_attr_op = 'setattribute'
    coerce_reg_type = 'P'
    goto type_done
  prim_int:
    get_attr_op = 'repr_get_attr_int'
    set_attr_op = 'repr_bind_attr_int'
    coerce_reg_type = 'I'
    goto type_done
  prim_num:
    get_attr_op = 'repr_get_attr_num'
    set_attr_op = 'repr_bind_attr_num'
    coerce_reg_type = 'N'
    goto type_done
  prim_str:
    get_attr_op = 'repr_get_attr_str'
    set_attr_op = 'repr_bind_attr_str'
    coerce_reg_type = 'S'
    goto type_done
  type_done:

    # We have three cases here.
    #   0 children = use self
    #   1 child    = object to look up on
    #   2 children = object to look up on + class handle
    # In the last case, we need to generate a different form of the op that
    # has the extra argument.
    .local pmc call_on
    $I0 = elements node
    if $I0 == 0 goto use_self
    call_on = node[0]
    call_on = self.'as_post'(call_on, 'rtype'=>'P')
    ops.'push'(call_on)
    if $I0 == 2 goto have_class_handle
    goto invocant_done
  use_self:
    call_on = box 'self'
  invocant_done:

    if bindpost goto attribute_bind

  attribute_post:
    .local pmc fetchop, storeop
    $P0 = get_hll_global ['POST'], 'Op'
    if coerce_reg_type == 'P' goto need_vivify
    $P1 = self.'uniquereg'(coerce_reg_type)
    fetchop = $P0.'new'($P1, call_on, name, 'pirop'=>get_attr_op)
    ops.'push'(fetchop)
    ops.'result'($P1)
    .return (ops)
  need_vivify:
    fetchop = $P0.'new'(ops, call_on, name, 'pirop'=>get_attr_op)
    storeop = $P0.'new'(call_on, name, ops, 'pirop'=>set_attr_op)
    .tailcall self.'vivify'(node, ops, fetchop, storeop)

  attribute_bind:
    if coerce_reg_type == 'P' goto attribute_bind_coerced    
    $P0 = self.'uniquereg'(coerce_reg_type)
    ops.'push_pirop'('set', $P0, bindpost)
    bindpost = $P0
  attribute_bind_coerced:
    ops.'push_pirop'(set_attr_op, call_on, name, bindpost)
    ops.'result'(bindpost)
    .return (ops)

  have_class_handle:
    .local pmc handle
    handle = node[1]
    handle = self.'as_post'(handle, 'rtype'=>'P')
    ops.'push'(handle)

    if bindpost goto attribute_bind_handle

    .local pmc fetchop, storeop
    $P0 = get_hll_global ['POST'], 'Op'
    if coerce_reg_type == 'P' goto need_vivify_handle
    $P1 = self.'uniquereg'(coerce_reg_type)
    fetchop = $P0.'new'($P1, call_on, handle, name, 'pirop'=>get_attr_op)
    ops.'push'(fetchop)
    ops.'result'($P1)
    .return (ops)
  need_vivify_handle:
    fetchop = $P0.'new'(ops, call_on, handle, name, 'pirop'=>get_attr_op)
    storeop = $P0.'new'(call_on, handle, name, ops, 'pirop'=>set_attr_op)
    .tailcall self.'vivify'(node, ops, fetchop, storeop)

  attribute_bind_handle:
    if coerce_reg_type == 'P' goto attribute_bind_handle_coerced
    $P0 = self.'uniquereg'(coerce_reg_type)
    ops.'push_pirop'('set', $P0, bindpost)
    bindpost = $P0
  attribute_bind_handle_coerced:
    ops.'push_pirop'(set_attr_op, call_on, handle, name, bindpost)
    ops.'result'(bindpost)
    .return (ops)
.end
