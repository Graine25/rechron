#include <rex/rex_app.h>
#include <rex/ppc/function.h>
#include <rex/runtime.h>
#include <rex/system/thread_state.h>
#include <rex/system/xthread.h>
#include <rex/logging.h>

#include "goliath_engine/kernel/guest_memory.h"

#include <type_traits>

#define REX_PPC_EXTERN_IMPORT(function) \
	REX_EXTERN(__imp__rex_##function)

#define REX_PPC_INVOKE(function, ...) \
	rex::GuestToHostFunction<function_return_t<decltype(function)>>(__imp__rex_##function, __VA_ARGS__)

#define REX_PPC_INVOKE2(return_type, function, ...) \
	rex::GuestToHostFunction<return_type>(__imp__rex_##function, __VA_ARGS__)

#define REX_PPC_HOOK(function) \
    REX_HOOK(rex_##function, function##_Hook)

#define REX_DATA_REFERENCE_DECLARE(address, type, name) \
	type& name = *static_cast<type*>(chron::kernel::memory::GuestAddressToHostMutable(address))

#define REX_DATA_REFERENCE_DECLARE_ARRAY(address, type, name, count) \
	type(&name)[count] = *static_cast<type(*)[count]>(chron::kernel::memory::GuestAddressToHostMutable(address))

#define REX_PPC_CONTEXT_REF(name) \
	auto current_thread = rex::system::XThread::GetCurrentThread(); \
	assert(current_thread != nullptr); \
	auto context = current_thread->thread_state()->context(); \
	assert(context != nullptr); \
	PPCContext& __restrict name = *context

#define REX_PPC_MEMBASE_PTR(name) \
auto* runtime = rex::Runtime::instance(); \
auto* memory = runtime->memory(); \
uint8_t* name = memory->virtual_membase()

template <typename t_type>
struct function_t;

template <typename t_return_type, typename... t_args>
struct function_t<t_return_type(t_args...)>
{
	using return_type = t_return_type;
};

template <typename t_return_type, typename... t_args>
struct function_t<t_return_type(*)(t_args...)>
{
	using return_type = t_return_type;
};

template <typename t_return_type, typename t_class, typename... t_args>
struct function_t<t_return_type(t_class::*)(t_args...)>
{
	using return_type = t_return_type;
};

template <typename t_return_type, typename t_class, typename... t_args>
struct function_t<t_return_type(t_class::*)(t_args...) const>
{
	using return_type = t_return_type;
};

template <typename t_function>
using function_return_t =
typename function_t<std::remove_cvref_t<t_function>>::return_type;
